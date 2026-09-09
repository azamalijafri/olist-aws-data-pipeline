SELECT
  c.customer_state,
  c.customer_city,
  COUNT(DISTINCT o.order_id) AS orders,
  ROUND(SUM(o.price), 2) AS revenue
FROM olist_gold.fact_order_items o
JOIN olist_gold.dim_customer c ON o.customer_id = c.customer_id
GROUP BY c.customer_state, c.customer_city
ORDER BY orders DESC
LIMIT 15;