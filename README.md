# Olist E-commerce Analytics Pipeline (AWS)

End-to-end medallion-architecture (bronze → silver → gold) data pipeline on AWS for the
[Olist Brazilian e-commerce dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce). Tables are **Apache Iceberg** in S3, ETL runs on
**AWS Glue 5.1 (Spark)**, analytics via **Athena**, orchestration via **Step Functions** — plus
streaming ingest (Kinesis → Lambda → S3/DynamoDB) and an optional **Redshift Serverless** path.

## Setup

1. Copy the environment template and fill in your values:

   ```sh
   cp .env.example .env
   ```

   All configuration lives in `.env` (account ID, region, bucket names, job specs, stream/Lambda
   names, Redshift password). No script hardcodes an account ID, bucket, or ARN.

2. Build once:

   ```sh
   bash scripts/s3.sh               # buckets, upload CSVs + ETL scripts
   bash scripts/iam.sh              # least-privilege roles
   bash scripts/glue-catalog.sh     # bronze/silver/gold databases
   bash scripts/glue-jobs.sh        # bronze/silver/gold Glue jobs
   bash scripts/stepfunctions.sh    # sequential orchestrator
   bash scripts/athena.sh           # sample queries (optional)
   bash scripts/kinesis.sh          # streaming: stream + bucket + metrics table
   bash scripts/lambda.sh           # Lambda consumer + event mapping
   bash scripts/redshift.sh         # Redshift Serverless (optional)
   ```

## Run the pipeline

```sh
aws stepfunctions start-execution \
  --state-machine-arn "arn:aws:states:${OLIST_REGION}:${OLIST_ACCOUNT}:stateMachine:${STATE_MACHINE}"
```

Each layer is written with `createOrReplace`, so reruns are idempotent and atomic per Iceberg
snapshot, and Iceberg time travel works via `FOR VERSION AS OF <snapshot_id>`.

## Verification

A known-good check on the gold layer: `SELECT SUM(payment_value) FROM olist_gold.fact_payments
WHERE date_key = 20181017` → **$89.71**. Full-run row counts are validated across all tables
(e.g. 103,886 payments, 112,650 order items).

## Cost

Everything is serverless/on-demand (Athena, Step Functions, Kinesis on-demand, job-driven Glue,
DynamoDB PAY_PER_REQUEST), so idle cost is near zero. Teardown is by explicit request only.
