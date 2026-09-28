#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_env.sh"

role_exists() {
  aws iam get-role --role-name "$1" >/dev/null 2>&1
}

ensure_role() {
  local name="$1" trust="$2" path="${3:-/}"
  if role_exists "$name"; then
    echo "SKIP role ${name} (exists)"
  else
    aws iam create-role \
      --role-name "${name}" \
      --path "${path}" \
      --assume-role-policy-document "file://${trust}"
    echo "OK role ${name}"
  fi
}

ensure_inline_policy() {
  local role="$1" policy="$2" doc="$3"
  aws iam put-role-policy \
    --role-name "${role}" \
    --policy-name "${policy}" \
    --policy-document "file://${doc}"
  echo "OK policy ${policy} on ${role}"
}

ensure_role "${ROLE_GLUE_SERVICE}" "${REPO_ROOT}/infra/iam/glue-trust-policy.json"
render "${REPO_ROOT}/infra/iam/glue-service-policy.json" /tmp/ol_glue_svc_policy.json
ensure_inline_policy "${ROLE_GLUE_SERVICE}" olist-glue-permissions /tmp/ol_glue_svc_policy.json

ensure_role "${ROLE_SFN}" "${REPO_ROOT}/infra/iam/sfn-trust-policy.json" "${SFN_ROLE_PATH}"
render "${REPO_ROOT}/infra/iam/sfn-service-policy.json" /tmp/ol_sfn_svc_policy.json
ensure_inline_policy "${ROLE_SFN}" olist-sfn-permissions /tmp/ol_sfn_svc_policy.json

ensure_role "${ROLE_LAMBDA}" "${REPO_ROOT}/infra/iam/lambda-trust-policy.json"
render "${REPO_ROOT}/infra/iam/lambda-policy.json" /tmp/ol_lambda_policy.json
ensure_inline_policy "${ROLE_LAMBDA}" olist-lambda-permissions /tmp/ol_lambda_policy.json

ensure_role "${ROLE_REDSHIFT}" "${REPO_ROOT}/infra/iam/redshift-trust-policy.json"