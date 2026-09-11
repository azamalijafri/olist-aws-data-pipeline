#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_env.sh"

aws dynamodb create-table \
  --table-name "${DDB_TABLE}" \
  --attribute-definitions '[{"AttributeName":"metric","AttributeType":"S"}]' \
  --key-schema '[{"AttributeName":"metric","KeyType":"HASH"}]' \
  --billing-mode PAY_PER_REQUEST \
  --region "${OLIST_REGION}"

aws dynamodb scan \
  --table-name "${DDB_TABLE}" \
  --region "${OLIST_REGION}" \
  --query 'Items'