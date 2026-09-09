SELECT
  s.seller_id,
  s.seller_state,
  ROUND(SUM(o.price), 2) AS revenue,
  COUNT(DISTINCT o.order_id) AS orders
FROM olist_gold.fact_order_items o
JOIN olist_gold.dim_seller s ON o.seller_id = s.seller_id
GROUP BY s.seller_id, s.seller_state
ORDER BY revenue DESC
LIMIT 10;