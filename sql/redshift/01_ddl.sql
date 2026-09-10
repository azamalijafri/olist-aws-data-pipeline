CREATE TABLE dim_customer (
  customer_id VARCHAR(64) PRIMARY KEY,
  customer_unique_id VARCHAR(64),
  customer_zip_code_prefix BIGINT,
  customer_city VARCHAR(100),
  customer_state VARCHAR(2)
);

CREATE TABLE dim_date (
  date_key INTEGER PRIMARY KEY,
  full_date DATE,
  year INTEGER,
  month INTEGER,
  day_of_month INTEGER,
  quarter INTEGER,
  week_of_year INTEGER,
  day_of_week INTEGER
);

CREATE TABLE dim_product (
  product_id VARCHAR(64) PRIMARY KEY,
  product_category VARCHAR(100),
  product_name_length BIGINT,
  product_description_length BIGINT,
  product_photos_qty BIGINT,
  product_weight_g BIGINT,
  product_length_cm BIGINT,
  product_height_cm BIGINT,
  product_width_cm BIGINT
);

CREATE TABLE dim_seller (
  seller_id VARCHAR(64) PRIMARY KEY,
  seller_zip_code_prefix BIGINT,
  seller_city VARCHAR(100),
  seller_state VARCHAR(2)
);

CREATE TABLE fact_order_items (
  order_id VARCHAR(64),
  order_item_id BIGINT,
  customer_id VARCHAR(64),
  product_id VARCHAR(64),
  seller_id VARCHAR(64),
  price DOUBLE PRECISION,
  freight_value DOUBLE PRECISION,
  date_key INTEGER,
  PRIMARY KEY (order_id, order_item_id)
)
DISTSTYLE KEY
DISTKEY (order_id)
SORTKEY (date_key);

CREATE TABLE fact_payments (
  order_id VARCHAR(64),
  payment_sequential BIGINT,
  payment_type VARCHAR(50),
  payment_installments BIGINT,
  payment_value DOUBLE PRECISION,
  date_key INTEGER,
  PRIMARY KEY (order_id, payment_sequential)
)
DISTSTYLE KEY
DISTKEY (order_id)
SORTKEY (date_key);