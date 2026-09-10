"""Read bronze Iceberg tables (raw strings), write typed Iceberg tables to the silver layer."""

from awsglue.context import GlueContext
from awsglue.job import Job
from awsglue.utils import getResolvedOptions
from pyspark.conf import SparkConf
from pyspark.context import SparkContext
from pyspark.sql.functions import col, date_format, to_date, to_timestamp, year


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


conf = job_conf(["SILVER_BUCKET", "CATALOG", "SOURCE_DB", "TARGET_DB"])
CATALOG = conf["CATALOG"]
SOURCE_DB = conf["SOURCE_DB"]
TARGET_DB = conf["TARGET_DB"]
WAREHOUSE = f"s3://{conf['SILVER_BUCKET']}"


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

RENAME = {
    "olist_products_dataset": {
        "product_name_lenght": "product_name_length",
        "product_description_lenght": "product_description_length",
    },
}

TIMESTAMP_COLS = {
    "olist_orders_dataset": [
        "order_purchase_timestamp",
        "order_approved_at",
        "order_delivered_carrier_date",
        "order_delivered_customer_date",
        "order_estimated_delivery_date",
    ],
    "olist_order_items_dataset": ["shipping_limit_date"],
    "olist_order_reviews_dataset": [
        "review_creation_date",
        "review_answer_timestamp",
    ],
}

DATE_COLS = {
    "olist_orders_dataset": "order_purchase_timestamp",
    "olist_order_items_dataset": "shipping_limit_date",
    "olist_order_reviews_dataset": "review_creation_date",
}


def main():
    sc = SparkContext(conf=ice_conf())
    glue_context = GlueContext(sc)
    spark = glue_context.spark_session
    job = Job(glue_context)
    job.init("olist-silver-etl", {})

    table_names = [
        "olist_customers_dataset",
        "olist_geolocation_dataset",
        "olist_order_items_dataset",
        "olist_order_payments_dataset",
        "olist_order_reviews_dataset",
        "olist_orders_dataset",
        "olist_products_dataset",
        "olist_sellers_dataset",
        "product_category_name_translation",
    ]

    for name in table_names:
        df = spark.table(f"{CATALOG}.{SOURCE_DB}.{name}")

        numeric = {
            "olist_customers_dataset": {"customer_zip_code_prefix": "long"},
            "olist_geolocation_dataset": {
                "geolocation_zip_code_prefix": "long",
                "geolocation_lat": "double",
                "geolocation_lng": "double",
            },
            "olist_order_items_dataset": {
                "order_item_id": "long",
                "price": "double",
                "freight_value": "double",
            },
            "olist_order_payments_dataset": {
                "payment_sequential": "long",
                "payment_installments": "long",
                "payment_value": "double",
            },
            "olist_order_reviews_dataset": {"review_score": "long"},
            "olist_products_dataset": {
                "product_name_length": "long",
                "product_description_length": "long",
                "product_photos_qty": "long",
                "product_weight_g": "long",
                "product_length_cm": "long",
                "product_height_cm": "long",
                "product_width_cm": "long",
            },
            "olist_sellers_dataset": {"seller_zip_code_prefix": "long"},
        }
        for c, t in numeric.get(name, {}).items():
            df = df.withColumn(c, col(c).cast(t))

        for c in TIMESTAMP_COLS.get(name, []):
            df = df.withColumn(c, to_timestamp(col(c), "yyyy-MM-dd HH:mm:ss"))
        if name in DATE_COLS:
            c = DATE_COLS[name]
            df = df.withColumn(c, to_date(col(c)))

        df = df.select(
            *[col(c).alias(RENAME.get(name, {}).get(c, c)) for c in df.columns]
        )

        if name in DATE_COLS:
            df = df.withColumn("year", year(col(DATE_COLS[name])))
            df.writeTo(f"{CATALOG}.{TARGET_DB}.{name}").partitionedBy(
                "year"
            ).createOrReplace()
        else:
            df.writeTo(f"{CATALOG}.{TARGET_DB}.{name}").createOrReplace()

        print(f"SILVER OK {name}: {df.count()} rows")

    job.commit()


if __name__ == "__main__":
    main()