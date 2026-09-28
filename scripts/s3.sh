#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_env.sh"

bucket_exists() {
  aws s3api head-bucket --bucket "$1" --region "${OLIST_REGION}" >/dev/null 2>&1
}

for b in "${BUCKET_RAW}" "${BUCKET_SILVER}" "${BUCKET_CURATED}" "${BUCKET_BRONZE}" "${BUCKET_CODE}" "${BUCKET_ATHENA}"; do
  if bucket_exists "$b"; then
    echo "SKIP bucket $b (exists)"
  else
    aws s3api create-bucket --bucket "$b" --region "${OLIST_REGION}"
    echo "OK bucket $b"
  fi
done

if [[ -d "${RAW_CSV_DIR}" ]]; then
  object_count="$(aws s3 ls "s3://${BUCKET_RAW}/" --region "${OLIST_REGION}" 2>/dev/null | wc -l)"
  if [[ "${object_count}" -eq 0 ]]; then
    for t in olist_customers_dataset olist_geolocation_dataset olist_order_items_dataset \
             olist_order_payments_dataset olist_order_reviews_dataset olist_orders_dataset \
             olist_products_dataset olist_sellers_dataset product_category_name_translation; do
      aws s3 cp "${RAW_CSV_DIR}/${t}.csv" "s3://${BUCKET_RAW}/${t}/" --region "${OLIST_REGION}"
    done
    echo "OK uploaded CSVs to raw"
  else
    echo "SKIP CSV upload (raw bucket already has ${object_count} objects)"
  fi
else
  echo "WARN RAW_CSV_DIR=${RAW_CSV_DIR} not found locally; keeping existing raw data"
fi

aws s3 cp "${REPO_ROOT}/${ETL_DIR}/etl_bronze.py" "s3://${BUCKET_CODE}/glue/etl_bronze.py" --region "${OLIST_REGION}"
aws s3 cp "${REPO_ROOT}/${ETL_DIR}/etl_silver.py" "s3://${BUCKET_CODE}/glue/etl_silver.py" --region "${OLIST_REGION}"
aws s3 cp "${REPO_ROOT}/${ETL_DIR}/etl_gold.py" "s3://${BUCKET_CODE}/glue/etl_gold.py" --region "${OLIST_REGION}"
echo "OK ETL scripts uploaded"