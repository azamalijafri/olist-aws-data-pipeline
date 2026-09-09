"""Read raw CSV catalog tables and write typed Parquet to the silver bucket."""

from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.context import SparkContext
from pyspark.sql.functions import col, to_date, to_timestamp, year

RAW_DB = "olist_raw"
SILVER_BUCKET = "s3://olist-silver-839553328980"

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
    sc = SparkContext()
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
        df = (
            glue_context.create_dynamic_frame.from_catalog(
                database=RAW_DB, table_name=name
            )
            .toDF()
        )

        for c in TIMESTAMP_COLS.get(name, []):
            df = df.withColumn(c, to_timestamp(col(c), "yyyy-MM-dd HH:mm:ss"))
        if name in DATE_COLS:
            c = DATE_COLS[name]
            df = df.withColumn(c, to_date(col(c), "yyyy-MM-dd"))

        df = df.select(
            *[col(c).alias(RENAME.get(name, {}).get(c, c)) for c in df.columns]
        )

        out_path = f"{SILVER_BUCKET}/{name}"
        if name in DATE_COLS:
            df = df.withColumn("year", year(col(DATE_COLS[name])))
            df.write.mode("overwrite").partitionBy("year").parquet(out_path)
        else:
            df.write.mode("overwrite").parquet(out_path)

        print(f"SILVER OK {name}: {df.count()} rows -> {out_path}")

    job.commit()


if __name__ == "__main__":
    main()