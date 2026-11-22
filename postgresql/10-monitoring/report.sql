\set d random(0, 700)
SELECT sum(amount) FROM orders
WHERE created_at >= timestamptz '2024-01-01' + :d * interval '1 day'
  AND created_at <  timestamptz '2024-01-01' + (:d + 1) * interval '1 day';
