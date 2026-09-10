SELECT
  payment_type,
  COUNT(*) AS payment_count,
  ROUND(SUM(payment_value), 2) AS total_value,
  ROUND(AVG(payment_value), 2) AS avg_value
FROM ${DB_GOLD}.fact_payments
GROUP BY payment_type
ORDER BY total_value DESC;