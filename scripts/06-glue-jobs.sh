#!/usr/bin/env bash

aws glue create-job \
  --name olist-silver-etl \
  --role olist-glue-service-role \
  --command '{"Name":"glueetl","ScriptLocation":"s3://olist-code-839553328980/glue/etl_silver.py","PythonVersion":"3"}' \
  --default-arguments '{"--job-bookmark-option":"job-bookmark-disable","--job-language":"python"}' \
  --glue-version 5.1 \
  --worker-type G.1X \
  --number-of-workers 2 \
  --timeout 30 \
  --region us-east-1

aws glue create-job \
  --name olist-gold-etl \
  --role olist-glue-service-role \
  --command '{"Name":"glueetl","ScriptLocation":"s3://olist-code-839553328980/glue/etl_gold.py","PythonVersion":"3"}' \
  --default-arguments '{"--job-bookmark-option":"job-bookmark-disable","--job-language":"python"}' \
  --glue-version 5.1 \
  --worker-type G.1X \
  --number-of-workers 2 \
  --timeout 30 \
  --region us-east-1