#!/usr/bin/env bash
set -euo pipefail
# Reference: Glue ETL jobs. Glue 5.1 ships Iceberg natively.
# Catalog config for the custom "olist_catalog" name lives in each script (ice_conf()
# via SparkConf) because the Glue bootstrap rejects a multi-valued --conf argument.
# Per-job config (buckets, catalog, database names) comes from .env and is passed as
# DefaultArguments so the ETL scripts stay resource-agnostic.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_env.sh"

CODE="s3://${BUCKET_CODE}/glue"
COMMON_JSON='{"--job-bookmark-option":"job-bookmark-disable","--job-language":"python","--datalake.formats":"iceberg"}'

# Glue passes DefaultArguments into the script's sys.argv; getResolvedOptions()
# matches keys with a leading "--", so every user config key is prefixed here.
job_args() {
  # job_args <raw-json>  -> DefaultArguments with each key prefixed by "--"
  python3 - "${COMMON_JSON}" "$1" <<'EOF'
import json, sys
base = json.loads(sys.argv[1]); extra = json.loads(sys.argv[2])
out = dict(base)
for k, v in extra.items():
    out["--" + k] = v
print(json.dumps(out))
EOF
}

put_job() {
  # put_job <name> <script> <args-json>  -> create-job, or update-job if it exists
  local name="$1" script="$2" args="$3"
  if aws glue get-job --job-name "${name}" --region "${OLIST_REGION}" >/dev/null 2>&1; then
    aws glue update-job \
      --job-name "${name}" \
      --job-update "{\"Role\":\"${ROLE_GLUE_SERVICE}\",\"Command\":{\"Name\":\"glueetl\",\"ScriptLocation\":\"${CODE}/${script}\",\"PythonVersion\":\"3\"},\"DefaultArguments\":${args},\"GlueVersion\":\"${GLUE_VERSION}\",\"WorkerType\":\"${GLUE_WORKER_TYPE}\",\"NumberOfWorkers\":${GLUE_WORKERS},\"Timeout\":${GLUE_TIMEOUT}}" \
      --region "${OLIST_REGION}" >/dev/null
  else
    aws glue create-job \
      --name "${name}" \
      --role "${ROLE_GLUE_SERVICE}" \
      --command "{\"Name\":\"glueetl\",\"ScriptLocation\":\"${CODE}/${script}\",\"PythonVersion\":\"3\"}" \
      --default-arguments "$args" \
      --glue-version "${GLUE_VERSION}" \
      --worker-type "${GLUE_WORKER_TYPE}" \
      --number-of-workers "${GLUE_WORKERS}" \
      --timeout "${GLUE_TIMEOUT}" \
      --region "${OLIST_REGION}" >/dev/null
  fi
  echo "OK job ${name}"
}

put_job "${JOB_BRONZE}" etl_bronze.py \
  "$(job_args "{\"RAW_BUCKET\":\"${BUCKET_RAW}\",\"BRONZE_BUCKET\":\"${BUCKET_BRONZE}\",\"CATALOG\":\"${GLUE_CATALOG}\",\"DB\":\"${DB_BRONZE}\"}")"

put_job "${JOB_SILVER}" etl_silver.py \
  "$(job_args "{\"SILVER_BUCKET\":\"${BUCKET_SILVER}\",\"CATALOG\":\"${GLUE_CATALOG}\",\"SOURCE_DB\":\"${DB_BRONZE}\",\"TARGET_DB\":\"${DB_SILVER}\"}")"

put_job "${JOB_GOLD}" etl_gold.py \
  "$(job_args "{\"CURATED_BUCKET\":\"${BUCKET_CURATED}\",\"CATALOG\":\"${GLUE_CATALOG}\",\"SOURCE_DB\":\"${DB_SILVER}\",\"TARGET_DB\":\"${DB_GOLD}\"}")"

aws glue get-jobs --region "${OLIST_REGION}" --query 'Jobs[].Name'