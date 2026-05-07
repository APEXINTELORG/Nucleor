SELECT
  group_id,
  SUM(value) AS total_value
FROM tiny_orders_table
WHERE value >= 10.0
GROUP BY group_id
ORDER BY group_id;
