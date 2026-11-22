\set cid random(1, 100000)
SELECT id, status, amount FROM orders WHERE customer_id = :cid;
SELECT id, name FROM customers WHERE lower(email) = 'user' || :cid || '@example.com';
SELECT id, customer_id, created_at FROM orders WHERE status = 'pending' ORDER BY created_at DESC LIMIT 10;
