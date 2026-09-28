#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_env.sh"

cd "${REPO_ROOT}/${LAMBDA_SRC}"
zip -q "${LAMBDA_ZIP}" lambda_function.py

if aws lambda get-function --function-name "${LAMBDA_FUNCTION}" --region "${OLIST_REGION}" >/dev/null 2>&1; then
  aws lambda update-function-code \
    --function-name "${LAMBDA_FUNCTION}" \
    --zip-file "fileb://${LAMBDA_ZIP}" \
    --region "${OLIST_REGION}" >/dev/null
  aws lambda update-function-configuration \
    --function-name "${LAMBDA_FUNCTION}" \
    --runtime "${LAMBDA_RUNTIME}" \
    --role "arn:aws:iam::${OLIST_ACCOUNT}:role/${ROLE_LAMBDA}" \
    --handler "${LAMBDA_HANDLER}" \
    --environment "{\"Variables\":{\"S3_BUCKET\":\"${BUCKET_STREAM}\",\"DDB_TABLE\":\"${DDB_TABLE}\"}}" \
    --memory-size "${LAMBDA_MEMORY}" \
    --timeout "${LAMBDA_TIMEOUT}" \
    --region "${OLIST_REGION}" >/dev/null
  echo "OK function ${LAMBDA_FUNCTION} updated"
else
  aws lambda create-function \
    --function-name "${LAMBDA_FUNCTION}" \
    --runtime "${LAMBDA_RUNTIME}" \
    --role "arn:aws:iam::${OLIST_ACCOUNT}:role/${ROLE_LAMBDA}" \
    --handler "${LAMBDA_HANDLER}" \
    --zip-file "fileb://${LAMBDA_ZIP}" \
    --environment "{\"Variables\":{\"S3_BUCKET\":\"${BUCKET_STREAM}\",\"DDB_TABLE\":\"${DDB_TABLE}\"}}" \
    --memory-size "${LAMBDA_MEMORY}" \
    --timeout "${LAMBDA_TIMEOUT}" \
    --region "${OLIST_REGION}" >/dev/null
  echo "OK function ${LAMBDA_FUNCTION} created"
fi

ESM_ARN="arn:aws:kinesis:${OLIST_REGION}:${OLIST_ACCOUNT}:stream/${KINESIS_STREAM}"
if aws lambda list-event-source-mappings \
     --function-name "${LAMBDA_FUNCTION}" \
     --event-source-arn "${ESM_ARN}" \
     --region "${OLIST_REGION}" \
     --query 'EventSourceMappings[0].UUID' --output text 2>/dev/null | grep -qE '[0-9a-f-]{36}'; then
  echo "SKIP event-source-mapping (exists)"
else
  aws lambda create-event-source-mapping \
    --function-name "${LAMBDA_FUNCTION}" \
    --event-source-arn "${ESM_ARN}" \
    --starting-position TRIM_HORIZON \
    --batch-size "${LAMBDA_BATCH_SIZE}" \
    --maximum-batching-window-in-seconds "${LAMBDA_BATCH_WINDOW}" \
    --region "${OLIST_REGION}" >/dev/null
  echo "OK event-source-mapping created for ${KINESIS_STREAM}"
fi

aws lambda get-function --function-name "${LAMBDA_FUNCTION}" --region "${OLIST_REGION}" \
  --query 'Configuration.State'