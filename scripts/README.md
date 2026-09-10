# scripts/

CLI reference commands for each AWS service used in the Olist medallion pipeline.
These are **reference-only** — they mirror what was configured in the AWS console, so
the whole project can be recreated from CLI. They are named by service, not numbered
in build order; the actual pipeline flow is the Step Functions state machine or the
documents in `infra/` and `glue/`.

For the database-creation + crawler era (schema-on-read, now retired) see `../legacy/`.

## Configuration

Requires a root `.env` file (copy `../.env.example`) holding account ID, bucket names,
job names, role names, etc. Every script sources `_env.sh`, which loads `.env`, exports
the values, and defines `render()`/`render_policy()` (envsubst helpers) used to substitute
`${VAR}` placeholders in IAM policies, the Step Functions ASL, and SQL templates. Nothing
in `scripts/`, `infra/`, `glue/`, or `sql/` hardcodes an account ID, ARN, or bucket.

| Script           | Service           | What it does                                             |
|------------------|-------------------|----------------------------------------------------------|
| `s3.sh`          | S3                | Zone buckets, bronze Iceberg warehouse, code + raw data  |
| `iam.sh`         | IAM               | Roles + inline policies for Glue, Step Functions, Lambda, Redshift |
| `glue-catalog.sh`| Glue Data Catalog | Bronze/silver/gold databases (Iceberg namespaces)        |
| `glue-jobs.sh`   | Glue (ETL)        | bronze/silver/gold jobs with `--datalake.formats=iceberg`|
| `athena.sh`      | Athena            | Gold BI queries + Iceberg snapshot/introspection         |
| `stepfunctions.sh| Step Functions    | 3-job sequential state machine (`startJobRun.sync`)      |
| `kinesis.sh`     | Kinesis           | `olist-events` stream (on-demand) + stream bucket         |
| `lambda.sh`      | Lambda            | `olist-stream-ingest` function + Kinesis event mapping   |
| `dynamodb.sh`    | DynamoDB          | `olist-live-metrics` table + scan                        |
| `redshift.sh`    | Redshift Serverless| Namespace + workgroup + COPY from curated bucket        |

Notes on the Iceberg setup:

- The custom catalog is named `olist_catalog` in the ETL scripts (`glue/*.py`), where
  `ice_conf()` registers it via `SparkConf`. It was intentionally **not** wired through
  the job's `--conf` DefaultArgument because the Glue bootstrap rejects a multi-key
  `--conf` value (LAUNCH ERROR "Invalid input to --conf").
- `--datalake.formats=iceberg` in `--default-arguments` is what Glue 5.1 uses to bundle
  the Iceberg runtime; the glue jars are already on the worker classpath.
- Per-job resource config (buckets, catalog, databases) is passed as `DefaultArguments`
  (sourced from `.env`); the ETL scripts fail fast if a required key is missing instead
  of falling back to hardcoded values.
- Athena addresses tables by database namespace only (`olist_gold.fact_payments`),
  since the account holds a single Glue Data Catalog; `olist_catalog` is a Spark-side
  label. Iceberg time travel (`FOR VERSION AS OF`) works from Athena.
- Warehouses per layer job: bronze→`olist-bronze-*`, silver→`olist-silver-*`,
  gold→`olist-curated-*`.