"""Build star-schema dimensions and facts from the silver tables."""

from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.context import SparkContext
from pyspark.sql.functions import (
    col,
    coalesce,
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

SILVER_DB = "olist_silver"
GOLD_BUCKET = "s3://olist-curated-839553328980"


def read_table(glue_context, name):
    return (
        glue_context.create_dynamic_frame.from_catalog(
            database=SILVER_DB, table_name=name
        )
        .toDF()
    )


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
        dim.withColumn("date_key", date_format(col("d"), "yyyyMMdd").cast("int"))
        .withColumn("full_date", col("d"))
        .withColumn("year", year(col("d")))
        .withColumn("month", month(col("d")))
        .withColumn("day_of_month", dayofmonth(col("d")))
        .withColumn("quarter", quarter(col("d")))
        .withColumn("week_of_year", weekofyear(col("d")))
        .withColumn("day_of_week", dayofweek(col("d")))
        .drop("d")
    )
    return dim


def main():
    sc = SparkContext()
    glue_context = GlueContext(sc)
    spark = glue_context.spark_session
    job = Job(glue_context)
    job.init("olist-gold-etl", {})

    customers = read_table(glue_context, "olist_customers_dataset")
    sellers = read_table(glue_context, "olist_sellers_dataset")
    products = read_table(glue_context, "olist_products_dataset")
    translation = read_table(glue_context, "product_category_name_translation")
    orders = read_table(glue_context, "olist_orders_dataset")
    items = read_table(glue_context, "olist_order_items_dataset")
    payments = read_table(glue_context, "olist_order_payments_dataset")

    dim_customer = customers.select(
        "customer_id",
        "customer_unique_id",
        "customer_zip_code_prefix",
        "customer_city",
        "customer_state",
    ).distinct()
    dim_customer.write.mode("overwrite").parquet(
        f"{GOLD_BUCKET}/dim_customer"
    )

    dim_seller = sellers.select(
        "seller_id",
        "seller_zip_code_prefix",
        "seller_city",
        "seller_state",
    ).distinct()
    dim_seller.write.mode("overwrite").parquet(f"{GOLD_BUCKET}/dim_seller")

    dim_product = (
        products.join(
            translation, on="product_category_name", how="left"
        )
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
    dim_product.write.mode("overwrite").parquet(
        f"{GOLD_BUCKET}/dim_product"
    )

    dim_date = build_dim_date(spark, orders)
    dim_date.write.mode("overwrite").parquet(f"{GOLD_BUCKET}/dim_date")

    orders_kv = orders.select(
        "order_id",
        "customer_id",
        col("order_purchase_timestamp"),
        date_format(col("order_purchase_timestamp"), "yyyyMMdd")
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
    fact_order_items.write.mode("overwrite").partitionBy("date_key").parquet(
        f"{GOLD_BUCKET}/fact_order_items"
    )

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
    fact_payments.write.mode("overwrite").partitionBy("date_key").parquet(
        f"{GOLD_BUCKET}/fact_payments"
    )

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