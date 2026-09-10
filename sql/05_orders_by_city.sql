SELECT
  c.customer_state,
  c.customer_city,
  COUNT(DISTINCT o.order_id) AS orders,
  ROUND(SUM(o.price), 2) AS revenue
FROM ${DB_GOLD}.fact_order_items o
JOIN ${DB_GOLD}.dim_customer c ON o.customer_id = c.customer_id
GROUP BY c.customer_state, c.customer_city
ORDER BY orders DESC
LIMIT 15;