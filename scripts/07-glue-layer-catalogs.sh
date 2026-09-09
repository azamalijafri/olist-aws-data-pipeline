#!/usr/bin/env bash

aws glue create-database \
  --database-input '{"Name":"olist_silver","Description":"Clean typed Olist tables"}' \
  --region us-east-1

aws glue create-crawler \
  --name olist-silver-crawler \
  --role olist-glue-crawler-role \
  --database-name olist_silver \
  --targets '{"S3Targets":[{"Path":"s3://olist-silver-839553328980/"}]}' \
  --schema-change-policy '{"UpdateBehavior":"UPDATE_IN_DATABASE","DeleteBehavior":"LOG"}' \
  --region us-east-1

aws glue start-crawler --name olist-silver-crawler --region us-east-1
aws glue get-tables --database-name olist_silver --query 'TableList[].Name' --region us-east-1

aws glue create-database \
  --database-input '{"Name":"olist_gold","Description":"Star schema analytical tables"}' \
  --region us-east-1

aws glue create-crawler \
  --name olist-gold-crawler \
  --role olist-glue-crawler-role \
  --database-name olist_gold \
  --targets '{"S3Targets":[{"Path":"s3://olist-curated-839553328980/"}]}' \
  --schema-change-policy '{"UpdateBehavior":"UPDATE_IN_DATABASE","DeleteBehavior":"LOG"}' \
  --region us-east-1

aws glue start-crawler --name olist-gold-crawler --region us-east-1
aws glue get-tables --database-name olist_gold --query 'TableList[].Name' --region us-east-1