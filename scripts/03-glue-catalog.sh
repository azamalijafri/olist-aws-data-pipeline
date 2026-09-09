#!/usr/bin/env bash

aws glue create-database \
  --database-input '{"Name":"olist_raw","Description":"Raw Olist landing tables"}' \
  --region us-east-1

aws glue create-crawler \
  --name olist-raw-crawler \
  --role olist-glue-crawler-role \
  --database-name olist_raw \
  --targets '{"S3Targets":[{"Path":"s3://olist-raw-839553328980/"}]}' \
  --schema-change-policy '{"UpdateBehavior":"UPDATE_IN_DATABASE","DeleteBehavior":"LOG"}' \
  --region us-east-1

aws glue start-crawler --name olist-raw-crawler --region us-east-1
aws glue get-tables --database-name olist_raw --query 'TableList[].Name' --region us-east-1