#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_env.sh"

RUN_STEPS=1
RUN_STREAMING=1

for a in "$@"; do
  case "$a" in
    --batch-only) RUN_STREAMING=0 ;;
    --full) RUN_STREAMING=1 ;;
    --no-run) RUN_STEPS=0 ;;
    *) echo "unknown arg: $a (use --batch-only | --full | --no-run)" >&2; exit 1 ;;
  esac
done

log() { echo; echo "[up] $*"; }

# --- 1. Storage + code ------------------------------------------------------
log "S3 buckets + ETL scripts"
bash "${SCRIPT_DIR}/s3.sh"

# --- 2. IAM -----------------------------------------------------------------
log "IAM roles + inline policies"
bash "${SCRIPT_DIR}/iam.sh"

# --- 3. Glue catalog --------------------------------------------------------
log "Glue catalog databases"
bash "${SCRIPT_DIR}/glue-catalog.sh"

# --- 4. Glue jobs -----------------------------------------------------------
log "Glue ETL jobs"
bash "${SCRIPT_DIR}/glue-jobs.sh"

# --- 5. Orchestrator --------------------------------------------------------
log "Step Functions state machine"
bash "${SCRIPT_DIR}/stepfunctions.sh"

# --- 6. Streaming -----------------------------------------------------------
if [[ "${RUN_STREAMING}" -eq 1 ]]; then
  log "Kinesis stream + DynamoDB table + stream bucket"
  bash "${SCRIPT_DIR}/kinesis.sh"
  log "Lambda consumer + event-source mapping"
  bash "${SCRIPT_DIR}/lambda.sh"
else
  log "SKIP streaming (--batch-only)"
fi

if [[ "${RUN_STEPS}" -eq 0 ]]; then
  log "DONE (--no-run; did not launch the pipeline)"
  exit 0
fi

# --- 7. Launch pipeline -----------------------------------------------------
SM_ARN="arn:aws:states:${OLIST_REGION}:${OLIST_ACCOUNT}:stateMachine:${STATE_MACHINE}"
log "start Step Functions execution"
EXEC_ARN="$(aws stepfunctions start-execution \
  --state-machine-arn "${SM_ARN}" \
  --region "${OLIST_REGION}" \
  --query 'executionArn' --output text)"
echo "execution: ${EXEC_ARN}"

log "waiting for pipeline (polls every 15s)"
for i in $(seq 1 40); do
  sleep 15
  STATUS="$(aws stepfunctions describe-execution --execution-arn "${EXEC_ARN}" --region "${OLIST_REGION}" --query 'status' --output text)"
  echo "  [${i}] ${STATUS}"
  case "${STATUS}" in
    SUCCEEDED) break ;;
    FAILED | TIMED_OUT | ABORTED)
      echo "pipeline ${STATUS}"
      aws stepfunctions get-execution-history --execution-arn "${EXEC_ARN}" --region "${OLIST_REGION}" \
        --query 'events[?type==`ExecutionFailed`].executionFailedEventDetails.error' --output text 2>/dev/null || true
      exit 1
      ;;
  esac
done

if [[ "${STATUS}" != "SUCCEEDED" ]]; then
  echo "pipeline still running after poll window; check ${EXEC_ARN}" >&2
  exit 1
fi

# --- 8. Verify --------------------------------------------------------------
log "verify: Athena known-good check"
QID="$(aws athena start-query-execution \
  --query-string "SELECT ROUND(SUM(payment_value),2) AS v FROM ${DB_GOLD}.fact_payments WHERE date_key=20181017" \
  --query-execution-context "{\"Database\":\"${DB_GOLD}\"}" \
  --result-configuration "{\"OutputLocation\":\"s3://${BUCKET_ATHENA}/${ATHENA_RESULTS_PREFIX}/\"}" \
  --region "${OLIST_REGION}" \
  --query 'QueryExecutionId' --output text)"
sleep 5
aws athena get-query-results --query-execution-id "${QID}" --region "${OLIST_REGION}" \
  --query 'ResultSet.Rows[].Data[].VarCharValue' --output text

log "pipeline is up: ${EXEC_ARN}"