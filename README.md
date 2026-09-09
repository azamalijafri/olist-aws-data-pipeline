# Olist E-commerce Analytics Pipeline (AWS)

End-to-end medallion-architecture data pipeline on AWS for the [Olist Brazilian e-commerce dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) (100k orders, 32.9k products, 3.1k sellers). Uses AWS Glue for Spark ETL, the Glue Data Catalog, and Athena for analytics, orchestrated end-to-end with Step Functions.

## Architecture

- **Bronze** — 9 raw CSVs land in S3 and are registered in the Glue catalog via crawlers.
- **Silver** — a Glue ETL job reads the raw tables and writes typed, year-partitioned Parquet (dates coercible from strings, schema corrections applied).
- **Gold** — a second Glue job builds a star schema (4 dimensions, 2 facts) with a date dimension generated from the actual order date range.
- **Analytics** — Athena queries (revenue by category/month, top sellers, payment mix, orders by city) run directly against the gold tables.
- **Orchestration** — a Step Functions state machine runs silver then gold sequentially, waiting on each job, so the whole pipeline is a single execution.

```
S3 (CSV) -> Glue ETL -> S3 (Parquet) -> Glue ETL -> S3 (star schema) -> Athena
```

## Tech stack

AWS Glue (Spark, PySpark) · Glue Data Catalog & Crawlers · S3 · Athena · Step Functions · IAM · shell scripts for reproducible setup

## Repository layout

```
.
|-- scripts/    # setup scripts, one per service layer (S3, IAM, Glue, Athena, Step Functions)
|-- glue/       # PySpark ETL jobs (silver + gold)
|-- sql/        # analytical queries
|-- infra/      # IAM policy documents + state machine definitions
```

## Running it

The pipeline is reproducible from the CLI in order:

```sh
bash scripts/01-s3.sh              # create buckets, upload CSVs
bash scripts/02-iam.sh             # least-privilege roles
bash scripts/03-glue-catalog.sh    # raw catalog: crawler + tables
bash scripts/06-glue-jobs.sh       # silver/gold Glue jobs
bash scripts/07-glue-layer-catalogs.sh  # silver/gold catalogs
bash scripts/09-stepfunctions.sh   # orchestrator
```

Each script mirrors the console configuration, and `scripts/README.md` documents the full order.

To refresh the data from end to end, run the `olist-etl-pipeline` state machine — it executes both Glue jobs and waits for each to complete.

## Sample insights

Run via Athena against the gold tables (queries in `sql/`):

- Top categories by revenue: `health_beauty` ($1.3M), `watches_gifts` ($1.2M), `bed_bath_table` ($1.0M)
- Monthly GMV grows from ~$14K (Oct 2016) to ~$1M (2018)
- Payments: 77% by credit card; top payment by volume is `credit_card` ($12.5M)
- São Paulo leads orders (15.4k), then Rio de Janeiro (6.8k)

## Reproducibility note

Account IDs and bucket names are parameterized; the account is `839553328980`. All resources are job-driven (no always-on compute), keeping cost near zero between runs.