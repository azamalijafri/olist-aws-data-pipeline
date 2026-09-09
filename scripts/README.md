# scripts/

Reproducible CLI commands configured in the AWS console during learning.
Scripts are numbered in the order the pipeline is built (01 = S3, 02 = IAM, ...).

Each script mirrors the console configuration for that service so the whole
pipeline can be recreated from these commands.

| Script | Service | Phase | What it does |
|--------|---------|-------|--------------|
| 01-s3.sh | S3 | 1 | Create zone buckets + upload raw CSVs |
| 02-iam.sh | IAM | 0.5 | Create least-privilege Glue service role |
| 03-glue-catalog.sh | Glue | 2 | DB + crawler + data catalog tables |
| 04-fix-raw-tables.sh | Glue | 2 | Manual authoring fallback for mis-schema'd raw tables |
| 05-fix-raw-crawlers.sh | Glue | 2 | Per-file classifiers + crawlers for all-string CSVs |
| 06-glue-jobs.sh | Glue | 3 | Create silver + gold ETL jobs |
| 07-glue-layer-catalogs.sh | Glue | 3 | Silver + gold databases and crawlers |
| 08-athena.sh | Athena | 4 | Run analytical SQL against gold catalog |
| 09-stepfunctions.sh | Step Functions | 5 | Orchestrate Glue jobs |
| 10-kinesis-lambda-dynamodb.sh | Streaming | 6 | Stream -> lambda -> s3 + dynamo |
| 11-emr.sh | EMR | 7 | Spot Spark analysis (optional) |
| 12-redshift.sh | Redshift | 8 | Serverless COPY + BI queries |

Order of operations: 01 -> 02 -> 03 -> (04|05) -> 06 -> 07 -> 08 -> 09 -> 10 -> (11) -> 12
