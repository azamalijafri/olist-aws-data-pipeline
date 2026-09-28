#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_env.sh"

PROTECTED_BUCKET="${BUCKET_RAW}"

log() { echo "[teardown] $*"; }

# --- Lambda -----------------------------------------------------------------
if ESM_UUID="$(aws lambda list-event-source-mappings \
     --function-name "${LAMBDA_FUNCTION}" \
     --region "${OLIST_REGION}" \
     --query 'EventSourceMappings[0].UUID' --output text 2>/dev/null)" && \
   [[ "${ESM_UUID}" =~ ^[0-9a-f-]{36}$ ]]; then
  aws lambda delete-event-source-mapping --uuid "${ESM_UUID}" --region "${OLIST_REGION}" >/dev/null
  log "deleted event-source-mapping ${ESM_UUID}"
else
  log "no event-source-mapping to delete"
fi

if aws lambda get-function --function-name "${LAMBDA_FUNCTION}" --region "${OLIST_REGION}" >/dev/null 2>&1; then
  aws lambda delete-function --function-name "${LAMBDA_FUNCTION}" --region "${OLIST_REGION}"
  log "deleted Lambda ${LAMBDA_FUNCTION}"
else
  log "Lambda ${LAMBDA_FUNCTION} not found"
fi

if aws logs delete-log-group --log-group-name "/aws/lambda/${LAMBDA_FUNCTION}" --region "${OLIST_REGION}" 2>/dev/null; then
  log "deleted log group /aws/lambda/${LAMBDA_FUNCTION}"
fi

# --- Kinesis ----------------------------------------------------------------
if aws kinesis describe-stream --stream-name "${KINESIS_STREAM}" --region "${OLIST_REGION}" >/dev/null 2>&1; then
  aws kinesis delete-stream --stream-name "${KINESIS_STREAM}" --region "${OLIST_REGION}"
  log "deleting stream ${KINESIS_STREAM}"
else
  log "stream ${KINESIS_STREAM} not found"
fi

# --- DynamoDB ---------------------------------------------------------------
if aws dynamodb describe-table --table-name "${DDB_TABLE}" --region "${OLIST_REGION}" >/dev/null 2>&1; then
  aws dynamodb delete-table --table-name "${DDB_TABLE}" --region "${OLIST_REGION}" >/dev/null
  log "deleted table ${DDB_TABLE}"
else
  log "table ${DDB_TABLE} not found"
fi

# --- Glue jobs + databases --------------------------------------------------
for j in "${JOB_BRONZE}" "${JOB_SILVER}" "${JOB_GOLD}"; do
  if aws glue get-job --job-name "${j}" --region "${OLIST_REGION}" >/dev/null 2>&1; then
    aws glue delete-job --job-name "${j}" --region "${OLIST_REGION}" >/dev/null
    log "deleted Glue job ${j}"
  else
    log "Glue job ${j} not found"
  fi
done

for db in "${DB_GOLD}" "${DB_SILVER}" "${DB_BRONZE}"; do
  if aws glue get-database --name "${db}" --region "${OLIST_REGION}" >/dev/null 2>&1; then
    aws glue delete-database --name "${db}" --region "${OLIST_REGION}" >/dev/null
    log "deleted database ${db}"
  else
    log "database ${db} not found"
  fi
done

# --- Step Functions ---------------------------------------------------------
SM_ARN="arn:aws:states:${OLIST_REGION}:${OLIST_ACCOUNT}:stateMachine:${STATE_MACHINE}"
if aws stepfunctions describe-state-machine --state-machine-arn "${SM_ARN}" --region "${OLIST_REGION}" >/dev/null 2>&1; then
  # Do not delete while an execution is running; omit stop so a running run finishes.
  if RUNNING="$(aws stepfunctions list-executions \
       --state-machine-arn "${SM_ARN}" --status-filter RUNNING --region "${OLIST_REGION}" \
       --query 'executions[0].executionArn' --output text 2>/dev/null)" && \
     [[ "${RUNNING}" =~ ^arn: ]]; then
    log "WARN state machine has a RUNNING execution; aborting it before delete"
    aws stepfunctions stop-execution --execution-arn "${RUNNING}" --region "${OLIST_REGION}" >/dev/null
  fi
  aws stepfunctions delete-state-machine --state-machine-arn "${SM_ARN}" --region "${OLIST_REGION}" >/dev/null
  log "deleted state machine ${STATE_MACHINE}"
else
  log "state machine ${STATE_MACHINE} not found"
fi

# --- Athena output buckets (not data; results only) -------------------------
delete_bucket() {
  local b="$1"
  if [[ "${b}" == "${PROTECTED_BUCKET}" ]]; then return; fi
  if ! aws s3api head-bucket --bucket "${b}" --region "${OLIST_REGION}" >/dev/null 2>&1; then
    log "bucket ${b} not found"
    return
  fi
  if aws s3 rb "s3://${b}" --force --region "${OLIST_REGION}" >/dev/null 2>&1; then
    log "deleted bucket ${b}"
  elif ! aws s3api head-bucket --bucket "${b}" --region "${OLIST_REGION}" >/dev/null 2>&1; then
    log "bucket ${b} already gone"
  else
    log "ERROR failed to delete bucket ${b}"
    return 1
  fi
}

for b in "${BUCKET_STREAM}" "${BUCKET_ATHENA}" olist-athena-results-"${OLIST_ACCOUNT}"; do
  delete_bucket "${b}"
done

# --- Data buckets (delete all EXCEPT raw seed) ------------------------------
for b in "${BUCKET_CURATED}" "${BUCKET_SILVER}" "${BUCKET_BRONZE}" "${BUCKET_CODE}"; do
  delete_bucket "${b}"
done

# --- CloudWatch log groups --------------------------------------------------
for lg in "/aws-glue/jobs/error" "/aws-glue/jobs/logs-v2" "/aws-glue/jobs/output" "/aws-glue/crawlers"; do
  if aws logs delete-log-group --log-group-name "${lg}" --region "${OLIST_REGION}" 2>/dev/null; then
    log "deleted log group ${lg}"
  fi
done

# --- IAM (detach inline policies, then delete role) -------------------------
delete_role() {
  local role="$1"
  if ! aws iam get-role --role-name "${role}" >/dev/null 2>&1; then
    log "role ${role} not found"
    return
  fi
  for p in $(aws iam list-role-policies --role-name "${role}" --query 'PolicyNames[]' --output text 2>/dev/null); do
    aws iam delete-role-policy --role-name "${role}" --policy-name "${p}" >/dev/null
    log "deleted inline policy ${p} from ${role}"
  done
  for a in $(aws iam list-attached-role-policies --role-name "${role}" --query 'AttachedPolicies[].PolicyArn' --output text 2>/dev/null); do
    aws iam detach-role-policy --role-name "${role}" --policy-arn "${a}" >/dev/null
    log "detached managed policy ${a} from ${role}"
  done
  aws iam delete-role --role-name "${role}"
  log "deleted role ${role}"
}

delete_role "${ROLE_GLUE_SERVICE}"
delete_role "${ROLE_LAMBDA}"
delete_role "${ROLE_SFN}"

# --- Summary ----------------------------------------------------------------
log "=== remaining olist buckets (expect only ${PROTECTED_BUCKET}) ==="
aws s3 ls 2>/dev/null | grep -i olist || echo "  (none)"
log "=== remaining olist roles ==="
aws iam list-roles --query 'Roles[].RoleName' --output text 2>/dev/null | tr '\t' '\n' | grep -i olist || echo "  (none)"
log "teardown complete"