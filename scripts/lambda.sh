#!/usr/bin/env bash
set -euo pipefail
# Reference: Lambda function consuming the Kinesis stream (see kinesis.sh).
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_env.sh"

envsubst < "${REPO_ROOT}/infra/iam/lambda-policy.json" > /tmp/ol_lambda_policy.json
aws iam put-role-policy \
  --role-name "${ROLE_LAMBDA}" \
  --policy-name olist-lambda-permissions \
  --policy-document file:///tmp/ol_lambda_policy.json

cd "${REPO_ROOT}/${LAMBDA_SRC}"
zip -q "${LAMBDA_ZIP}" lambda_function.py

aws lambda create-function \
  --function-name "${LAMBDA_FUNCTION}" \
  --runtime "${LAMBDA_RUNTIME}" \
  --role "arn:aws:iam::${OLIST_ACCOUNT}:role/${ROLE_LAMBDA}" \
  --handler "${LAMBDA_HANDLER}" \
  --zip-file "fileb://${LAMBDA_ZIP}" \
  --environment "{\"Variables\":{\"S3_BUCKET\":\"${BUCKET_STREAM}\",\"DDB_TABLE\":\"${DDB_TABLE}\"}}" \
  --memory-size "${LAMBDA_MEMORY}" \
  --timeout "${LAMBDA_TIMEOUT}" \
  --region "${OLIST_REGION}"

aws lambda create-event-source-mapping \
  --function-name "${LAMBDA_FUNCTION}" \
  --event-source-arn "arn:aws:kinesis:${OLIST_REGION}:${OLIST_ACCOUNT}:stream/${KINESIS_STREAM}" \
  --starting-position TRIM_HORIZON \
  --batch-size "${LAMBDA_BATCH_SIZE}" \
  --maximum-batching-window-in-seconds "${LAMBDA_BATCH_WINDOW}" \
  --region "${OLIST_REGION}"

aws lambda get-function --function-name "${LAMBDA_FUNCTION}" --region "${OLIST_REGION}" \
  --query 'Configuration.State'