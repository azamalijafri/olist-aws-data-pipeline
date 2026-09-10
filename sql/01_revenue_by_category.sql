SELECT
  p.product_category,
  ROUND(SUM(o.price), 2) AS gross_revenue,
  COUNT(DISTINCT o.order_id) AS distinct_orders,
  SUM(CASE WHEN o.order_item_id = 1 THEN 1 ELSE 0 END) AS first_item_count
FROM ${DB_GOLD}.fact_order_items o
JOIN ${DB_GOLD}.dim_product p ON o.product_id = p.product_id
GROUP BY p.product_category
ORDER BY gross_revenue DESC
LIMIT 20;