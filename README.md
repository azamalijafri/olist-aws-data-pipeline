# Olist E-commerce Analytics Pipeline

A medallion data lake (bronze → silver → gold) on AWS, built over the
[Olist Brazilian e-commerce dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce)
— ~100k orders, 1M+ order items, and nine CSVs covering payments, reviews, sellers and products.

Tables are Apache Iceberg in S3, transformed with AWS Glue 5.1 (Spark 3.5.6), queried through
Athena, and chained in Step Functions. There's also a separate streaming path that pushes live
events through Kinesis into Lambda, landing them in S3 and a small DynamoDB metrics table.

## How it runs

```
s3://olist-raw-*/csv  →  olist_bronze  →  olist_silver  →  olist_gold
   raw CSVs              typed          deduped, joined   star schema
```

Bronze is schema-on-read over the CSVs, silver does the real cleanup, gold builds the star
schema (`fact_payments`, `fact_order_items`, `dim_customer`, `dim_product`, `dim_seller`,
`dim_date`) — that's the layer you actually query.

Each layer is written with `createOrReplace`, so reruns are atomic and idempotent: one new
Iceberg snapshot instead of a half-written table. It also buys time travel via
`FOR VERSION AS OF <snapshot_id>`.

The streaming side (`producer.py` → Kinesis → Lambda → S3 + DynamoDB) is deliberately *not*
part of that chain. It's there to show a real-time path with live counters, and gold doesn't
depend on it.

## Running it

```sh
cp .env.example .env    # fill in account id, region, bucket names
bash scripts/up.sh      # build everything, run the pipeline, verify
```

`up.sh` is the whole thing end to end — S3 and Glue scripts, IAM, catalog, the three Glue
jobs, the state machine, the streaming resources, then it fires an execution and waits.
About 6–7 minutes, mostly Glue cold starts. `--batch-only` skips streaming, `--no-run` just
builds the infra.

Any of the `scripts/*.sh` files can be run on their own and re-run safely.

## Checking it worked

```sql
SELECT SUM(payment_value) FROM olist_gold.fact_payments WHERE date_key = 20181017;
```

Should be **89.71** — a fixed number from a known-good run, so if it shifts after a rebuild
something broke. Row counts should match too (103,886 payments, 112,650 order items, 99,441
customers).

## Cost

Everything is on-demand and job-driven, so idle cost is basically nothing.

```sh
bash scripts/teardown.sh   # removes everything except the raw bucket
```

Run it whenever you're not using the project. `bash scripts/up.sh` brings it all back.
