#!/usr/bin/env bash
set -euo pipefail
# Reference: Redshift Serverless. COPY gold data for BI queries (see sql/redshift/).
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_env.sh"

: "${REDSHIFT_ADMIN_PASSWORD:?set REDSHIFT_ADMIN_PASSWORD in .env}"

aws iam create-role \
  --role-name "${ROLE_REDSHIFT}" \
  --assume-role-policy-document file://${REPO_ROOT}/infra/iam/redshift-trust-policy.json \
  --description "Least-privilege role for Redshift Serverless to COPY from the curated bucket"

envsubst < "${REPO_ROOT}/infra/iam/redshift-service-policy.json" > /tmp/ol_redshift_svc_policy.json
aws iam put-role-policy \
  --role-name "${ROLE_REDSHIFT}" \
  --policy-name olist-redshift-permissions \
  --policy-document file:///tmp/ol_redshift_svc_policy.json

aws redshift-serverless create-namespace \
  --namespace-name "${REDSHIFT_NAMESPACE}" \
  --admin-user "${REDSHIFT_ADMIN_USER}" \
  --admin-user-password "${REDSHIFT_ADMIN_PASSWORD}" \
  --db-name "${REDSHIFT_DB}" \
  --iam-role "arn:aws:iam::${OLIST_ACCOUNT}:role/${ROLE_REDSHIFT}" \
  --region "${OLIST_REGION}"

aws redshift-serverless create-workgroup \
  --namespace-name "${REDSHIFT_NAMESPACE}" \
  --workgroup-name "${REDSHIFT_WORKGROUP}" \
  --base-capacity "${REDSHIFT_BASE_CAPACITY}" \
  --region "${OLIST_REGION}"

aws redshift-serverless wait namespace-available \
  --namespace-name "${REDSHIFT_NAMESPACE}" --region "${OLIST_REGION}"
aws redshift-serverless wait workgroup-available \
  --workgroup-name "${REDSHIFT_WORKGROUP}" --region "${OLIST_REGION}"

aws redshift-serverless get-workgroup \
  --workgroup-name "${REDSHIFT_WORKGROUP}" --region "${OLIST_REGION}" \
  --query 'workgroup.{endpoint:endpoint.address,port:endpoint.port,name:workgroupName}' \
  --output json