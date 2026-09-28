#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_env.sh"

ensure_database() {
  local name="$1" desc="$2" uri="$3"
  if aws glue get-database --name "${name}" --region "${OLIST_REGION}" >/dev/null 2>&1; then
    echo "SKIP database ${name} (exists)"
  else
    aws glue create-database \
      --database-input "{\"Name\":\"${name}\",\"Description\":\"${desc}\",\"LocationUri\":\"${uri}\"}" \
      --region "${OLIST_REGION}"
    echo "OK database ${name}"
  fi
}

ensure_database "${DB_BRONZE}" "Bronze: raw CSV strings as Iceberg tables" "s3://${BUCKET_BRONZE}/"
ensure_database "${DB_SILVER}" "Silver: typed, deduplicated, year-partitioned" "s3://${BUCKET_SILVER}/"
ensure_database "${DB_GOLD}" "Gold: star-schema dims + facts" "s3://${BUCKET_CURATED}/"

aws glue get-databases --region "${OLIST_REGION}" --query 'DatabaseList[].Name'