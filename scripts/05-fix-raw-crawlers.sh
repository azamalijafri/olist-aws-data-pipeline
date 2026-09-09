#!/usr/bin/env bash

aws glue delete-classifier --name olist-csv-header --region us-east-1

aws glue create-classifier \
  --csv-classifier '{
    "Name": "olist-csv-orders",
    "Delimiter": ",",
    "QuoteSymbol": "\"",
    "ContainsHeader": "PRESENT",
    "Header": ["order_id","customer_id","order_status","order_purchase_timestamp","order_approved_at","order_delivered_carrier_date","order_delivered_customer_date","order_estimated_delivery_date"]
  }' \
  --region us-east-1

aws glue create-classifier \
  --csv-classifier '{
    "Name": "olist-csv-translation",
    "Delimiter": ",",
    "QuoteSymbol": "\"",
    "ContainsHeader": "PRESENT",
    "Header": ["product_category_name","product_category_name_english"]
  }' \
  --region us-east-1

aws glue update-crawler \
  --name olist-raw-crawler \
  --role olist-glue-crawler-role \
  --database-name olist_raw \
  --targets '{"S3Targets":[{"Path":"s3://olist-raw-839553328980/","Exclusions":["**/olist_orders_dataset/**","**/product_category_name_translation/**"]}]}' \
  --region us-east-1

aws glue create-crawler \
  --name olist-raw-orders-crawler \
  --role olist-glue-crawler-role \
  --database-name olist_raw \
  --classifiers '["olist-csv-orders"]' \
  --targets '{"S3Targets":[{"Path":"s3://olist-raw-839553328980/olist_orders_dataset/"}]}' \
  --region us-east-1

aws glue create-crawler \
  --name olist-raw-translation-crawler \
  --role olist-glue-crawler-role \
  --database-name olist_raw \
  --classifiers '["olist-csv-translation"]' \
  --targets '{"S3Targets":[{"Path":"s3://olist-raw-839553328980/product_category_name_translation/"}]}' \
  --region us-east-1

aws glue delete-table --database-name olist_raw --name olist_orders_dataset --region us-east-1
aws glue delete-table --database-name olist_raw --name product_category_name_translation --region us-east-1

aws glue start-crawler --name olist-raw-crawler --region us-east-1
aws glue start-crawler --name olist-raw-orders-crawler --region us-east-1
aws glue start-crawler --name olist-raw-translation-crawler --region us-east-1

aws glue get-table --database-name olist_raw --name olist_orders_dataset --query 'Table.StorageDescriptor.Columns[].Name' --output text --region us-east-1
aws glue get-table --database-name olist_raw --name product_category_name_translation --query 'Table.StorageDescriptor.Columns[].Name' --output text --region us-east-1