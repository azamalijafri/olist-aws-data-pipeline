#!/usr/bin/env bash

aws athena start-query-execution \
  --query-string "SELECT * FROM olist_gold.dim_customer LIMIT 5" \
  --query-execution-context '{"Database":"olist_gold"}' \
  --result-configuration '{"OutputLocation":"s3://olist-athena-839553328980/results/"}' \
  --region us-east-1

aws athena start-query-execution \
  --query-string file://../sql/01_revenue_by_category.sql \
  --query-execution-context '{"Database":"olist_gold"}' \
  --result-configuration '{"OutputLocation":"s3://olist-athena-839553328980/results/"}' \
  --region us-east-1

aws athena start-query-execution \
  --query-string file://../sql/02_monthly_gmv.sql \
  --query-execution-context '{"Database":"olist_gold"}' \
  --result-configuration '{"OutputLocation":"s3://olist-athena-839553328980/results/"}' \
  --region us-east-1

aws athena start-query-execution \
  --query-string file://../sql/03_top_sellers.sql \
  --query-execution-context '{"Database":"olist_gold"}' \
  --result-configuration '{"OutputLocation":"s3://olist-athena-839553328980/results/"}' \
  --region us-east-1

aws athena start-query-execution \
  --query-string file://../sql/04_payments_by_type.sql \
  --query-execution-context '{"Database":"olist_gold"}' \
  --result-configuration '{"OutputLocation":"s3://olist-athena-839553328980/results/"}' \
  --region us-east-1

aws athena start-query-execution \
  --query-string file://../sql/05_orders_by_city.sql \
  --query-execution-context '{"Database":"olist_gold"}' \
  --result-configuration '{"OutputLocation":"s3://olist-athena-839553328980/results/"}' \
  --region us-east-1