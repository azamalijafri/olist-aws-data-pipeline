#!/usr/bin/env bash
set -euo pipefail
# Reference: Kinesis stream + DynamoDB metrics table for the streaming ingest.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_env.sh"

aws kinesis create-stream \
  --stream-name "${KINESIS_STREAM}" \
  --stream-mode-details '{"StreamMode":"ON_DEMAND"}' \
  --region "${OLIST_REGION}"

aws dynamodb create-table \
  --table-name "${DDB_TABLE}" \
  --attribute-definitions '[{"AttributeName":"metric","AttributeType":"S"}]' \
  --key-schema '[{"AttributeName":"metric","KeyType":"HASH"}]' \
  --billing-mode PAY_PER_REQUEST \
  --region "${OLIST_REGION}"

aws s3 mb "s3://${BUCKET_STREAM}" --region "${OLIST_REGION}"

aws kinesis describe-stream --stream-name "${KINESIS_STREAM}" --region "${OLIST_REGION}" \
  --query 'StreamDescription.StreamStatus'