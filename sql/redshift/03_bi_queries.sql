SELECT
  p.product_category,
  ROUND(SUM(o.price), 2) AS gross_revenue,
  COUNT(DISTINCT o.order_id) AS distinct_orders,
  SUM(CASE WHEN o.order_item_id = 1 THEN 1 ELSE 0 END) AS first_item_count
FROM fact_order_items o
JOIN dim_product p ON o.product_id = p.product_id
GROUP BY p.product_category
ORDER BY gross_revenue DESC
LIMIT 20;

SELECT
  d.year,
  d.month,
  ROUND(SUM(o.price) + SUM(o.freight_value), 2) AS gmv
FROM fact_order_items o
JOIN dim_date d ON o.date_key = d.date_key
GROUP BY d.year, d.month
ORDER BY d.year, d.month;

SELECT
  s.seller_id,
  s.seller_state,
  ROUND(SUM(o.price), 2) AS revenue,
  COUNT(DISTINCT o.order_id) AS orders
FROM fact_order_items o
JOIN dim_seller s ON o.seller_id = s.seller_id
GROUP BY s.seller_id, s.seller_state
ORDER BY revenue DESC
LIMIT 10;

SELECT
  payment_type,
  COUNT(*) AS payment_count,
  ROUND(SUM(payment_value), 2) AS total_value,
  ROUND(AVG(payment_value), 2) AS avg_value
FROM fact_payments
GROUP BY payment_type
ORDER BY total_value DESC;

SELECT
  c.customer_state,
  c.customer_city,
  COUNT(DISTINCT o.order_id) AS orders,
  ROUND(SUM(o.price), 2) AS revenue
FROM fact_order_items o
JOIN dim_customer c ON o.customer_id = c.customer_id
GROUP BY c.customer_state, c.customer_city
ORDER BY orders DESC
LIMIT 15;