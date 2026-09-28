#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_env.sh"

if aws dynamodb describe-table --table-name "${DDB_TABLE}" --region "${OLIST_REGION}" >/dev/null 2>&1; then
  echo "SKIP table ${DDB_TABLE} (exists)"
else
  aws dynamodb create-table \
    --table-name "${DDB_TABLE}" \
    --attribute-definitions '[{"AttributeName":"metric","AttributeType":"S"},{"AttributeName":"day","AttributeType":"S"}]' \
    --key-schema '[{"AttributeName":"metric","KeyType":"HASH"},{"AttributeName":"day","KeyType":"RANGE"}]' \
    --billing-mode PAY_PER_REQUEST \
    --region "${OLIST_REGION}"
  echo "OK table ${DDB_TABLE}"
fi

if aws s3api head-bucket --bucket "${BUCKET_STREAM}" --region "${OLIST_REGION}" >/dev/null 2>&1; then
  echo "SKIP bucket ${BUCKET_STREAM} (exists)"
else
  aws s3api create-bucket --bucket "${BUCKET_STREAM}" --region "${OLIST_REGION}"
  echo "OK bucket ${BUCKET_STREAM}"
fi

if aws kinesis describe-stream --stream-name "${KINESIS_STREAM}" --region "${OLIST_REGION}" >/dev/null 2>&1; then
  echo "SKIP stream ${KINESIS_STREAM} (exists)"
  STATUS="$(aws kinesis describe-stream --stream-name "${KINESIS_STREAM}" --region "${OLIST_REGION}" --query 'StreamDescription.StreamStatus' --output text)"
else
  aws kinesis create-stream \
    --stream-name "${KINESIS_STREAM}" \
    --stream-mode-details '{"StreamMode":"ON_DEMAND"}' \
    --region "${OLIST_REGION}"
  echo "OK stream ${KINESIS_STREAM} (waiting for ACTIVE)"
  aws kinesis wait stream-exists --stream-name "${KINESIS_STREAM}" --region "${OLIST_REGION}"
  STATUS="$(aws kinesis describe-stream --stream-name "${KINESIS_STREAM}" --region "${OLIST_REGION}" --query 'StreamDescription.StreamStatus' --output text)"
fi

echo "stream ${KINESIS_STREAM}: ${STATUS}"