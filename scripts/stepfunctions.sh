#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_env.sh"

SM_ARN="arn:aws:states:${OLIST_REGION}:${OLIST_ACCOUNT}:stateMachine:${STATE_MACHINE}"

render "${REPO_ROOT}/infra/stepfunctions/olist-etl-pipeline.asl.json" /tmp/olist-etl-pipeline-asl.json

aws stepfunctions create-state-machine \
  --name "${STATE_MACHINE}" \
  --definition file:///tmp/olist-etl-pipeline-asl.json \
  --role-arn "arn:aws:iam::${OLIST_ACCOUNT}:role${SFN_ROLE_PATH}${ROLE_SFN}" \
  --type STANDARD \
  --region "${OLIST_REGION}"

aws stepfunctions start-execution \
  --state-machine-arn "${SM_ARN}" \
  --region "${OLIST_REGION}"