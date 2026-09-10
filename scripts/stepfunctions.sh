#!/usr/bin/env bash
set -euo pipefail
# Reference: Step Functions. Orchestrate the 3 Glue jobs in sequence (bronze -> silver -> gold).
# Uses the startJobRun.sync optimized integration; JSONata query language.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_env.sh"

SM_ARN="arn:aws:states:${OLIST_REGION}:${OLIST_ACCOUNT}:stateMachine:${STATE_MACHINE}"

# The ASL template references ${JOB_BRONZE/SILVER/GOLD}; render from .env first.
render "${REPO_ROOT}/infra/stepfunctions/olist-etl-pipeline.asl.json" /tmp/olist-etl-pipeline-asl.json

aws stepfunctions create-state-machine \
  --name "${STATE_MACHINE}" \
  --definition file:///tmp/olist-etl-pipeline-asl.json \
  --role-arn "arn:aws:iam::${OLIST_ACCOUNT}:role${SFN_ROLE_PATH}${ROLE_SFN}" \
  --type STANDARD \
  --region "${OLIST_REGION}"

# Manual trigger:
aws stepfunctions start-execution \
  --state-machine-arn "${SM_ARN}" \
  --region "${OLIST_REGION}"