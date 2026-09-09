#!/usr/bin/env bash

aws s3api create-bucket --bucket olist-raw-839553328980 --region us-east-1
aws s3api create-bucket --bucket olist-curated-839553328980 --region us-east-1
aws s3api create-bucket --bucket olist-code-839553328980 --region us-east-1
aws s3api create-bucket --bucket olist-athena-839553328980 --region us-east-1

aws s3 cp /home/azam/Downloads/archive/olist_customers_dataset.csv s3://olist-raw-839553328980/olist_customers_dataset/
aws s3 cp /home/azam/Downloads/archive/olist_geolocation_dataset.csv s3://olist-raw-839553328980/olist_geolocation_dataset/
aws s3 cp /home/azam/Downloads/archive/olist_order_items_dataset.csv s3://olist-raw-839553328980/olist_order_items_dataset/
aws s3 cp /home/azam/Downloads/archive/olist_order_payments_dataset.csv s3://olist-raw-839553328980/olist_order_payments_dataset/
aws s3 cp /home/azam/Downloads/archive/olist_order_reviews_dataset.csv s3://olist-raw-839553328980/olist_order_reviews_dataset/
aws s3 cp /home/azam/Downloads/archive/olist_orders_dataset.csv s3://olist-raw-839553328980/olist_orders_dataset/
aws s3 cp /home/azam/Downloads/archive/olist_products_dataset.csv s3://olist-raw-839553328980/olist_products_dataset/
aws s3 cp /home/azam/Downloads/archive/olist_sellers_dataset.csv s3://olist-raw-839553328980/olist_sellers_dataset/
aws s3 cp /home/azam/Downloads/archive/product_category_name_translation.csv s3://olist-raw-839553328980/product_category_name_translation/
