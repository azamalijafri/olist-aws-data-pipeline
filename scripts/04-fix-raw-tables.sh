#!/usr/bin/env bash

aws glue create-table \
  --database-name olist_raw \
  --table-input '{
    "Name": "olist_orders_dataset",
    "StorageDescriptor": {
      "Columns": [
        {"Name":"order_id","Type":"string"},
        {"Name":"customer_id","Type":"string"},
        {"Name":"order_status","Type":"string"},
        {"Name":"order_purchase_timestamp","Type":"timestamp"},
        {"Name":"order_approved_at","Type":"timestamp"},
        {"Name":"order_delivered_carrier_date","Type":"timestamp"},
        {"Name":"order_delivered_customer_date","Type":"timestamp"},
        {"Name":"order_estimated_delivery_date","Type":"timestamp"}
      ],
      "Location": "s3://olist-raw-839553328980/olist_orders_dataset/",
      "InputFormat": "org.apache.hadoop.mapred.TextInputFormat",
      "OutputFormat": "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat",
      "SerdeInfo": {
        "SerializationLibrary": "org.apache.hadoop.hive.serde2.lazy.LazySimpleSerDe",
        "Parameters": {"field.delim": ","}
      },
      "Parameters": {
        "classification": "csv",
        "delimiter": ",",
        "columnsOrdered": "true",
        "areColumnsQuoted": "false",
        "typeOfData": "file",
        "skip.header.line.count": "1"
      }
    }
  }' \
  --region us-east-1

aws glue create-table \
  --database-name olist_raw \
  --table-input '{
    "Name": "product_category_name_translation",
    "StorageDescriptor": {
      "Columns": [
        {"Name":"product_category_name","Type":"string"},
        {"Name":"product_category_name_english","Type":"string"}
      ],
      "Location": "s3://olist-raw-839553328980/product_category_name_translation/",
      "InputFormat": "org.apache.hadoop.mapred.TextInputFormat",
      "OutputFormat": "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat",
      "SerdeInfo": {
        "SerializationLibrary": "org.apache.hadoop.hive.serde2.lazy.LazySimpleSerDe",
        "Parameters": {"field.delim": ","}
      },
      "Parameters": {
        "classification": "csv",
        "delimiter": ",",
        "columnsOrdered": "true",
        "areColumnsQuoted": "false",
        "typeOfData": "file",
        "skip.header.line.count": "1"
      }
    }
  }' \
  --region us-east-1

aws glue get-tables --database-name olist_raw --query 'TableList[].Name' --region us-east-1