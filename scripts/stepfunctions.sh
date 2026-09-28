#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_env.sh"

SM_ARN="arn:aws:states:${OLIST_REGION}:${OLIST_ACCOUNT}:stateMachine:${STATE_MACHINE}"

render "${REPO_ROOT}/infra/stepfunctions/olist-etl-pipeline.asl.json" /tmp/olist-etl-pipeline-asl.json

if aws stepfunctions describe-state-machine --state-machine-arn "${SM_ARN}" --region "${OLIST_REGION}" >/dev/null 2>&1; then
  aws stepfunctions update-state-machine \
    --state-machine-arn "${SM_ARN}" \
    --definition file:///tmp/olist-etl-pipeline-asl.json \
    --role-arn "arn:aws:iam::${OLIST_ACCOUNT}:role${SFN_ROLE_PATH}${ROLE_SFN}" \
    --region "${OLIST_REGION}" >/dev/null
  echo "OK state machine ${STATE_MACHINE} updated"
else
  aws stepfunctions create-state-machine \
    --name "${STATE_MACHINE}" \
    --definition file:///tmp/olist-etl-pipeline-asl.json \
    --role-arn "arn:aws:iam::${OLIST_ACCOUNT}:role${SFN_ROLE_PATH}${ROLE_SFN}" \
    --type STANDARD \
    --region "${OLIST_REGION}" >/dev/null
  echo "OK state machine ${STATE_MACHINE} created"
fi