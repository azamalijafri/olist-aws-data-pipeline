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

aws dynamodb scan \
  --table-name "${DDB_TABLE}" \
  --region "${OLIST_REGION}" \
  --query 'Items'