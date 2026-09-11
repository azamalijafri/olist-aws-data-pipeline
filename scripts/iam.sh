#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_env.sh"

aws iam create-role \
  --role-name "${ROLE_GLUE_SERVICE}" \
  --assume-role-policy-document file://${REPO_ROOT}/infra/iam/glue-trust-policy.json \
  --description "Least-privilege Glue service role for the Iceberg ETL jobs"

envsubst < "${REPO_ROOT}/infra/iam/glue-service-policy.json" > /tmp/ol_glue_svc_policy.json
aws iam put-role-policy \
  --role-name "${ROLE_GLUE_SERVICE}" \
  --policy-name olist-glue-permissions \
  --policy-document file:///tmp/ol_glue_svc_policy.json

aws iam create-role \
  --role-name "${ROLE_SFN}" \
  --path "${SFN_ROLE_PATH}" \
  --assume-role-policy-document file://${REPO_ROOT}/infra/iam/sfn-trust-policy.json \
  --description "Least-privilege role for the Step Functions ETL pipeline"

envsubst < "${REPO_ROOT}/infra/iam/sfn-service-policy.json" > /tmp/ol_sfn_svc_policy.json
aws iam put-role-policy \
  --role-name "${ROLE_SFN}" \
  --policy-name olist-sfn-permissions \
  --policy-document file:///tmp/ol_sfn_svc_policy.json

aws iam create-role \
  --role-name "${ROLE_LAMBDA}" \
  --assume-role-policy-document file://${REPO_ROOT}/infra/iam/lambda-trust-policy.json

aws iam create-role \
  --role-name "${ROLE_REDSHIFT}" \
  --assume-role-policy-document file://${REPO_ROOT}/infra/iam/redshift-trust-policy.json
