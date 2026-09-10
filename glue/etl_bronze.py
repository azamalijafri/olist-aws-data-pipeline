"""Read raw CSV files with explicit schemas and write immutable Iceberg tables to the bronze layer."""

from awsglue.context import GlueContext
from awsglue.job import Job
from awsglue.utils import getResolvedOptions
from pyspark.conf import SparkConf
from pyspark.context import SparkContext
from pyspark.sql.types import (
    StringType,
    StructField,
    StructType,
)


def job_conf(required_keys):
    import sys

    try:
        resolved = getResolvedOptions(sys.argv, required_keys)
    except SystemExit:
        raise SystemExit(
            f"Missing required job arguments. Pass them as --ArgKey VALUE or via DefaultArguments. "
            f"Required: {', '.join(required_keys)}"
        )
    return resolved


conf = job_conf(["RAW_BUCKET", "BRONZE_BUCKET", "CATALOG", "DB"])
RAW_BUCKET = f"s3://{conf['RAW_BUCKET']}"
CATALOG = conf["CATALOG"]
DB = conf["DB"]
WAREHOUSE = f"s3://{conf['BRONZE_BUCKET']}"


def ice_conf():
    return (
        SparkConf()
        .set("spark.sql.extensions", "org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions")
        .set("spark.sql.catalog.spark_catalog", "org.apache.iceberg.spark.SparkSessionCatalog")
        .set("spark.sql.catalog.spark_catalog.type", "hive")
        .set(f"spark.sql.catalog.{CATALOG}", "org.apache.iceberg.spark.SparkCatalog")
        .set(f"spark.sql.catalog.{CATALOG}.catalog-impl", "org.apache.iceberg.aws.glue.GlueCatalog")
        .set(f"spark.sql.catalog.{CATALOG}.io-impl", "org.apache.iceberg.aws.s3.S3FileIO")
        .set(f"spark.sql.catalog.{CATALOG}.warehouse", WAREHOUSE)
        .set("spark.sql.sources.partitionOverwriteMode", "dynamic")
    )

TABLE_SCHEMAS = {
    "olist_customers_dataset": [
        "customer_id",
        "customer_unique_id",
        "customer_zip_code_prefix",
        "customer_city",
        "customer_state",
    ],
    "olist_geolocation_dataset": [
        "geolocation_zip_code_prefix",
        "geolocation_lat",
        "geolocation_lng",
        "geolocation_city",
        "geolocation_state",
    ],
    "olist_order_items_dataset": [
        "order_id",
        "order_item_id",
        "product_id",
        "seller_id",
        "shipping_limit_date",
        "price",
        "freight_value",
    ],
    "olist_order_payments_dataset": [
        "order_id",
        "payment_sequential",
        "payment_type",
        "payment_installments",
        "payment_value",
    ],
    "olist_order_reviews_dataset": [
        "review_id",
        "order_id",
        "review_score",
        "review_comment_title",
        "review_comment_message",
        "review_creation_date",
        "review_answer_timestamp",
    ],
    "olist_orders_dataset": [
        "order_id",
        "customer_id",
        "order_status",
        "order_purchase_timestamp",
        "order_approved_at",
        "order_delivered_carrier_date",
        "order_delivered_customer_date",
        "order_estimated_delivery_date",
    ],
    "olist_products_dataset": [
        "product_id",
        "product_category_name",
        "product_name_length",
        "product_description_length",
        "product_photos_qty",
        "product_weight_g",
        "product_length_cm",
        "product_height_cm",
        "product_width_cm",
    ],
    "olist_sellers_dataset": [
        "seller_id",
        "seller_zip_code_prefix",
        "seller_city",
        "seller_state",
    ],
    "product_category_name_translation": [
        "product_category_name",
        "product_category_name_english",
    ],
}


def build_schema(columns):
    return StructType([StructField(c, StringType(), True) for c in columns])


def main():
    sc = SparkContext(conf=ice_conf())
    glue_context = GlueContext(sc)
    spark = glue_context.spark_session
    job = Job(glue_context)
    job.init("olist-bronze-etl", {})

    for name, cols in TABLE_SCHEMAS.items():
        df = (
            spark.read.option("header", True)
            .option("quote", '"')
            .option("escape", '"')
            .option("emptyValue", "")
            .schema(build_schema(cols))
            .csv(f"{RAW_BUCKET}/{name}/{name}.csv")
        )
        df.writeTo(f"{CATALOG}.{DB}.{name}").createOrReplace()

        print(f"BRONZE OK {name}: {df.count()} rows")

    job.commit()


if __name__ == "__main__":
    main()