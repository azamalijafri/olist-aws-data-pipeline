#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_env.sh"

RT="s3://${BUCKET_ATHENA}/${ATHENA_RESULTS_PREFIX}/"

aws athena start-query-execution \
  --query-string "SELECT * FROM ${DB_GOLD}.dim_customer LIMIT 5" \
  --query-execution-context "{\"Database\":\"${DB_GOLD}\"}" \
  --result-configuration "{\"OutputLocation\":\"${RT}\"}" \
  --region "${OLIST_REGION}"

for q in "${REPO_ROOT}/${SQL_DIR}"/0*.sql; do
  render "$q" /tmp/olist-bi.sql
  aws athena start-query-execution \
    --query-string "file:///tmp/olist-bi.sql" \
    --query-execution-context "{\"Database\":\"${DB_GOLD}\"}" \
    --result-configuration "{\"OutputLocation\":\"${RT}\"}" \
    --region "${OLIST_REGION}"
done

aws athena start-query-execution \
  --query-string "SELECT snapshot_id, committed_at FROM ${DB_GOLD}.\"fact_payments\$snapshots\" ORDER BY committed_at" \
  --query-execution-context "{\"Database\":\"${DB_GOLD}\"}" \
  --result-configuration "{\"OutputLocation\":\"${RT}\"}" \
  --region "${OLIST_REGION}"