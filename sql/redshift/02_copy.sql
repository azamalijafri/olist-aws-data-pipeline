-- Reference COPY statements. Pre-Iceberg proof: expects the old Parquet table
-- layout under the curated bucket. Iceberg gold tables live under
-- s3://${BUCKET_CURATED}/olist_gold.db/<table>/ and require EXTERNAL schemas +
-- a different source path, so this file is kept as a historical proof of COPY.
--
-- Render placeholders from .env before running:
--   envsubst < sql/redshift/02_copy.sql | psql ...
COPY dim_customer
FROM 's3://${BUCKET_CURATED}/dim_customer/'
IAM_ROLE 'arn:aws:iam::${OLIST_ACCOUNT}:role/${ROLE_REDSHIFT}'
FORMAT AS PARQUET;

COPY dim_date
FROM 's3://${BUCKET_CURATED}/dim_date/'
IAM_ROLE 'arn:aws:iam::${OLIST_ACCOUNT}:role/${ROLE_REDSHIFT}'
FORMAT AS PARQUET;

COPY dim_product
FROM 's3://${BUCKET_CURATED}/dim_product/'
IAM_ROLE 'arn:aws:iam::${OLIST_ACCOUNT}:role/${ROLE_REDSHIFT}'
FORMAT AS PARQUET;

COPY dim_seller
FROM 's3://${BUCKET_CURATED}/dim_seller/'
IAM_ROLE 'arn:aws:iam::${OLIST_ACCOUNT}:role/${ROLE_REDSHIFT}'
FORMAT AS PARQUET;

COPY fact_order_items
FROM 's3://${BUCKET_CURATED}/fact_order_items/'
IAM_ROLE 'arn:aws:iam::${OLIST_ACCOUNT}:role/${ROLE_REDSHIFT}'
FORMAT AS PARQUET
PARTITION BY (date_key);

COPY fact_payments
FROM 's3://${BUCKET_CURATED}/fact_payments/'
IAM_ROLE 'arn:aws:iam::${OLIST_ACCOUNT}:role/${ROLE_REDSHIFT}'
FORMAT AS PARQUET
PARTITION BY (date_key);