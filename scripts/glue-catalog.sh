#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_env.sh"

aws glue create-database --database-input "{\"Name\":\"${DB_BRONZE}\",\"Description\":\"Bronze: raw CSV strings as Iceberg tables\",\"LocationUri\":\"s3://${BUCKET_BRONZE}/\"}" --region "${OLIST_REGION}"
aws glue create-database --database-input "{\"Name\":\"${DB_SILVER}\",\"Description\":\"Silver: typed, deduplicated, year-partitioned\",\"LocationUri\":\"s3://${BUCKET_SILVER}/\"}" --region "${OLIST_REGION}"
aws glue create-database --database-input "{\"Name\":\"${DB_GOLD}\",\"Description\":\"Gold: star-schema dims + facts\",\"LocationUri\":\"s3://${BUCKET_CURATED}/\"}" --region "${OLIST_REGION}"

aws glue get-databases --region "${OLIST_REGION}" --query 'DatabaseList[].Name'