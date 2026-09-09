#!/usr/bin/env bash

aws iam create-role \
  --role-name olist-sfn-role \
  --assume-role-policy-document file://../infra/iam/sfn-trust-policy.json \
  --description "Least-privilege role for the Olist Step Functions pipeline"

aws iam put-role-policy \
  --role-name olist-sfn-role \
  --policy-name olist-sfn-permissions \
  --policy-document file://../infra/iam/sfn-service-policy.json

aws stepfunctions create-state-machine \
  --name olist-etl-pipeline \
  --definition file://../infra/stepfunctions/olist-etl-pipeline.asl.json \
  --role-arn arn:aws:iam::839553328980:role/olist-sfn-role \
  --type STANDARD \
  --region us-east-1