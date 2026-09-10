#!/usr/bin/env bash
set -euo pipefail
# Reference: S3 buckets. Zone buckets + zone-bronze (Iceberg warehouse) + code + athena.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_env.sh"

aws s3api create-bucket --bucket "${BUCKET_RAW}" --region "${OLIST_REGION}"
aws s3api create-bucket --bucket "${BUCKET_SILVER}" --region "${OLIST_REGION}"
aws s3api create-bucket --bucket "${BUCKET_CURATED}" --region "${OLIST_REGION}"
aws s3api create-bucket --bucket "${BUCKET_BRONZE}" --region "${OLIST_REGION}"
aws s3api create-bucket --bucket "${BUCKET_CODE}" --region "${OLIST_REGION}"
aws s3api create-bucket --bucket "${BUCKET_ATHENA}" --region "${OLIST_REGION}"

# Raw landing data (already in the raw bucket from the initial load):
#   olist_customers_dataset, olist_geolocation_dataset, olist_order_items_dataset,
#   olist_order_payments_dataset, olist_order_reviews_dataset, olist_orders_dataset,
#   olist_products_dataset, olist_sellers_dataset, product_category_name_translation
for t in olist_customers_dataset olist_geolocation_dataset olist_order_items_dataset \
         olist_order_payments_dataset olist_order_reviews_dataset olist_orders_dataset \
         olist_products_dataset olist_sellers_dataset product_category_name_translation; do
  aws s3 cp "${RAW_CSV_DIR}/${t}.csv" "s3://${BUCKET_RAW}/${t}/"
done

# ETL scripts
aws s3 cp "${REPO_ROOT}/${ETL_DIR}/etl_bronze.py" "s3://${BUCKET_CODE}/glue/etl_bronze.py"
aws s3 cp "${REPO_ROOT}/${ETL_DIR}/etl_silver.py" "s3://${BUCKET_CODE}/glue/etl_silver.py"
aws s3 cp "${REPO_ROOT}/${ETL_DIR}/etl_gold.py" "s3://${BUCKET_CODE}/glue/etl_gold.py"