# Olist E-commerce Analytics Pipeline (AWS)

End-to-end medallion-architecture data pipeline on AWS for the
[Olist Brazilian e-commerce dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce)
(100k orders, 32.9k products, 3.1k sellers): **Apache Iceberg tables** in S3, ETL with
AWS Glue (Spark) registered in the Glue Data Catalog, analytics with Athena, and full
orchestration with Step Functions — plus streaming ingest and a Redshift Serverless proof.

## Why Iceberg

The first version of this pipeline used Glue **crawlers** for schema-on-read. That works
but has real limits:

- Crawlers re-infer schemas from CSV on every refresh, and headerless files ended up as
  `col0..colN`; fixing that required per-file classifier crawlers plus heuristic "healer"
  crawlers to repair the raw tables, and the whole definition ballooned to 24 state-machine
  steps with no transactional guarantees.
- Tables are immutable files; schema evolution and data fixes mean rewriting everything.

Iceberg gives **ACID commits, time travel (`FOR TIMESTAMP/VERSION AS OF`), schema evolution,
hidden partitioning, and snapshot isolation** at the table level, and Glue 5.1 ships the
Iceberg runtime natively. The crawlers are gone — each layer's tables are created and
replaced atomically by the ETL job itself (`createOrReplace`).

## Architecture

```
s3://olist-raw-*        (CSVs, landed as-is)
        │  Glue job: olist-bronze-etl   (Iceberg: read CSV w/ explicit schema, write strings)
        ▼
s3://olist-bronze-*     Iceberg tables: olist_bronze.* (9 tables, raw strings)
        │  Glue job: olist-silver-etl   (Iceberg: cast numeric/timestamp/date, partition by year)
        ▼
s3://olist-silver-*     Iceberg tables: olist_silver.* (9 tables, typed, year-partitioned)
        │  Glue job: olist-gold-etl     (Iceberg: star schema + date dimension)
        ▼
s3://olist-curated-*    Iceberg tables: olist_gold.* (4 dims + 2 facts, date_key-partitioned)
        │
        ├── Athena      BI queries (sql/*.sql) + time travel
        └── Redshift Serverless  COPY gold -> sql/redshift/* (optional proof)

Step Functions (olist-etl-pipeline): RunBronzeEtl → RunSilverEtl → RunGoldEtl → Succeed
   (startJobRun.sync; each job waits for the previous to finish)

Streaming path (parallel, standalone):
   Kinesis olist-events (on-demand) → Lambda olist-stream-ingest → S3 olist-stream-* + DynamoDB olist-live-metrics
```

- **One Glue Data Catalog per account.** Databases (`olist_bronze`, `olist_silver`,
  `olist_gold`) are the namespaces. The ETL scripts use a Spark-side catalog label
  `olist_catalog` (see `scripts/README.md` for why it isn't a `--conf`); Athena just uses
  the database namespace.
- Warehouses per layer: bronze→`olist-bronze-*`, silver→`olist-silver-*`, gold→`olist-curated-*`.
- No always-on compute: everything is job/query driven, so the cost is near zero between runs.

## Configuration

All configuration lives in a root `.env` file (copy `.env.example` and fill it in). Every
`scripts/*.sh` sources `scripts/_env.sh`, which loads `.env` and exports the values; no
script hardcodes an account ID, bucket name, or ARN. Policy documents, the Step Functions
ASL, and Athena/ Redshift SQL templates reference `${VAR}` placeholders that are rendered
from `.env` via `envsubst` at apply/run time.

```sh
cp .env.example .env     # then edit OLIST_ACCOUNT, bucket names, REDSHIFT_ADMIN_PASSWORD, ...
```

## Repository layout

```
.
|-- .env.example # template; copy to .env and fill
|-- scripts/    # CLI reference per AWS service (s3, iam, glue-catalog, glue-jobs, athena, stepfunctions, kinesis, lambda, dynamodb, redshift) + _env.sh loader + README index
|-- infra/      # IAM trust/policy documents + Step Functions ASL (${VAR} templated)
|-- glue/       # PySpark ETL jobs: etl_bronze.py, etl_silver.py, etl_gold.py (Iceberg)
|-- sql/        # analytical queries for Athena + Redshift copy/DDL/BI (${VAR} templated)
|-- lambdas/    # kinesis_ingest lambda_function.py (streaming)
|-- data/       # catalog schema snapshots + Athena query results
|-- legacy/     # retired crawler-based pipeline artifacts (byte-identical originals)
```

## Build order (run once)

```sh
bash scripts/s3.sh               # buckets (incl. bronze Iceberg warehouse), upload CSVs + ETL scripts
bash scripts/iam.sh              # least-privilege roles
bash scripts/glue-catalog.sh     # bronze/silver/gold databases
bash scripts/glue-jobs.sh        # bronze/silver/gold Glue jobs (--datalake.formats=iceberg)
bash scripts/stepfunctions.sh    # orchestrator (3-job sequential state machine)
bash scripts/athena.sh           # sample queries (optional)
# streaming:
bash scripts/kinesis.sh          # stream + stream bucket + metrics table
bash scripts/lambda.sh           # Lambda consumer + event mapping
# redshift (optional proof):
bash scripts/redshift.sh         # namespace/workgroup + set REDSHIFT_ADMIN_PASSWORD in .env
```

> Scripts are reference/idempotent-ish: most `create-*` calls fail if the resource already
> exists (verified live earlier), which is fine for a run-once build.

## Refresh the data end to end

```sh
aws stepfunctions start-execution \
  --state-machine-arn "arn:aws:states:${OLIST_REGION}:${OLIST_ACCOUNT}:stateMachine:${STATE_MACHINE}"
```
Each job uses `createOrReplace`, so reruns are idempotent and atomic per Iceberg snapshot.

## Time travel (Iceberg)

Gold `fact_payments` accumulates a new snapshot per run. From Athena:

```sql
-- current view
SELECT COUNT(*) FROM olist_gold.fact_payments;

-- view as of an earlier snapshot (use a real snapshot_id)
SELECT * FROM olist_gold.fact_payments FOR VERSION AS OF <snapshot_id> LIMIT 5;

-- list snapshots
SELECT snapshot_id, committed_at FROM olist_gold."fact_payments$snapshots" ORDER BY committed_at;
```

## Sample insights (queries in `sql/`)

- Top categories by revenue: `health_beauty` ($1.26M), `watches_gifts` ($1.21M), `bed_bath_table` ($1.04M)
- Monthly GMV grows from ~$14K (Oct 2016) to ~$1M/month in 2018
- Payments: credit card dominates (76.8k payments, $12.5M)
- São Paulo leads orders (15.4k), then Rio de Janeiro (6.8k)
- Known-good check: `fact_payments` for date_key `20181017` = **$89.71** (matches the crawler-era run)

## Cost notes

- Budget: ~$20 cap for the whole project. Beefier numbers only when running.
- Athena, Step Functions, Kinesis (on-demand) and job-driven Glue keep idle cost near zero.
- All resources are per-run; teardown is by explicit request only.