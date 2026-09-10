SELECT
  d.year,
  d.month,
  ROUND(SUM(o.price) + SUM(o.freight_value), 2) AS gmv
FROM ${DB_GOLD}.fact_order_items o
JOIN ${DB_GOLD}.dim_date d ON CAST(o.date_key AS INT) = d.date_key
GROUP BY d.year, d.month
ORDER BY d.year, d.month;