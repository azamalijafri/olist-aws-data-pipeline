#!/usr/bin/env bash

aws iam create-role \
  --role-name olist-glue-service-role \
  --assume-role-policy-document file://../infra/iam/glue-trust-policy.json \
  --description "Least-privilege Glue service role for Olist ETL"

aws iam put-role-policy \
  --role-name olist-glue-service-role \
  --policy-name olist-glue-permissions \
  --policy-document file://../infra/iam/glue-service-policy.json

aws iam create-role \
  --role-name olist-glue-crawler-role \
  --assume-role-policy-document file://../infra/iam/glue-trust-policy.json \
  --description "Least-privilege role for the Olist raw crawler"

aws iam put-role-policy \
  --role-name olist-glue-crawler-role \
  --policy-name olist-crawler-permissions \
  --policy-document file://../infra/iam/glue-crawler-policy.json
