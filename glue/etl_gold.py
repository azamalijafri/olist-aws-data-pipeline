"""Read silver Iceberg tables, build star-schema dimensions and facts in the gold layer."""

from awsglue.context import GlueContext
from awsglue.job import Job
from awsglue.utils import getResolvedOptions
from pyspark.conf import SparkConf
from pyspark.context import SparkContext
from pyspark.sql.functions import (
    coalesce,
    col,
    date_format,
    dayofmonth,
    dayofweek,
    max as _max,
    min as _min,
    month,
    quarter,
    weekofyear,
    year,
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


conf = job_conf(["CURATED_BUCKET", "CATALOG", "SOURCE_DB", "TARGET_DB"])
CATALOG = conf["CATALOG"]
SOURCE_DB = conf["SOURCE_DB"]
TARGET_DB = conf["TARGET_DB"]
WAREHOUSE = f"s3://{conf['CURATED_BUCKET']}"


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


def read_table(spark, name):
    return spark.table(f"{CATALOG}.{SOURCE_DB}.{name}")


def build_dim_date(spark, orders):
    bounds = orders.agg(
        _min("order_purchase_timestamp").alias("min_d"),
        _max("order_purchase_timestamp").alias("max_d"),
    ).first()
    start = bounds.min_d.strftime("%Y-%m-%d")
    end = bounds.max_d.strftime("%Y-%m-%d")
    dim = spark.sql(
        f"SELECT explode(sequence(to_date('{start}'), to_date('{end}'), interval 1 day)) AS d"
    )
    dim = (
        dim.withColumn("date_key", date_format("d", "yyyyMMdd").cast("int"))
        .withColumn("full_date", col("d"))
        .withColumn("year", year("d"))
        .withColumn("month", month("d"))
        .withColumn("day_of_month", dayofmonth("d"))
        .withColumn("quarter", quarter("d"))
        .withColumn("week_of_year", weekofyear("d"))
        .withColumn("day_of_week", dayofweek("d"))
        .drop("d")
    )
    return dim


def main():
    sc = SparkContext(conf=ice_conf())
    glue_context = GlueContext(sc)
    spark = glue_context.spark_session
    job = Job(glue_context)
    job.init("olist-gold-etl", {})

    customers = read_table(spark, "olist_customers_dataset")
    sellers = read_table(spark, "olist_sellers_dataset")
    products = read_table(spark, "olist_products_dataset")
    translation = read_table(spark, "product_category_name_translation")
    orders = read_table(spark, "olist_orders_dataset")
    items = read_table(spark, "olist_order_items_dataset")
    payments = read_table(spark, "olist_order_payments_dataset")

    dim_customer = customers.select(
        "customer_id",
        "customer_unique_id",
        "customer_zip_code_prefix",
        "customer_city",
        "customer_state",
    ).distinct()
    dim_customer.writeTo(f"{CATALOG}.{TARGET_DB}.dim_customer").createOrReplace()

    dim_seller = sellers.select(
        "seller_id",
        "seller_zip_code_prefix",
        "seller_city",
        "seller_state",
    ).distinct()
    dim_seller.writeTo(f"{CATALOG}.{TARGET_DB}.dim_seller").createOrReplace()

    dim_product = (
        products.join(translation, on="product_category_name", how="left")
        .select(
            products["product_id"],
            coalesce(
                col("product_category_name_english"),
                col("product_category_name"),
            ).alias("product_category"),
            "product_name_length",
            "product_description_length",
            "product_photos_qty",
            "product_weight_g",
            "product_length_cm",
            "product_height_cm",
            "product_width_cm",
        )
        .distinct()
    )
    dim_product.writeTo(f"{CATALOG}.{TARGET_DB}.dim_product").createOrReplace()

    dim_date = build_dim_date(spark, orders)
    dim_date.writeTo(f"{CATALOG}.{TARGET_DB}.dim_date").createOrReplace()

    orders_kv = orders.select(
        "order_id",
        "customer_id",
        "order_purchase_timestamp",
        date_format("order_purchase_timestamp", "yyyyMMdd")
        .cast("int")
        .alias("date_key"),
    )

    fact_order_items = (
        items.join(orders_kv, on="order_id", how="left")
        .select(
            "order_id",
            "order_item_id",
            "customer_id",
            "product_id",
            "seller_id",
            "date_key",
            "price",
            "freight_value",
        )
    )
    fact_order_items.writeTo(f"{CATALOG}.{TARGET_DB}.fact_order_items") \
        .partitionedBy("date_key").createOrReplace()

    fact_payments = (
        payments.join(orders_kv, on="order_id", how="left")
        .select(
            "order_id",
            "payment_sequential",
            "payment_type",
            "payment_installments",
            "payment_value",
            "date_key",
        )
    )
    fact_payments.writeTo(f"{CATALOG}.{TARGET_DB}.fact_payments") \
        .partitionedBy("date_key").createOrReplace()

    for name, df in [
        ("dim_customer", dim_customer),
        ("dim_seller", dim_seller),
        ("dim_product", dim_product),
        ("dim_date", dim_date),
        ("fact_order_items", fact_order_items),
        ("fact_payments", fact_payments),
    ]:
        print(f"GOLD OK {name}: {df.count()} rows")

    job.commit()


if __name__ == "__main__":
    main()