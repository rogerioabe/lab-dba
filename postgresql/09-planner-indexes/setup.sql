-- Lesson 13 dataset: 100k customers, 2M orders, no secondary indexes yet.
DROP TABLE IF EXISTS orders, customers;

CREATE TABLE customers (
    id         int PRIMARY KEY,
    name       text NOT NULL,
    email      text NOT NULL,
    country    text NOT NULL,
    city       text NOT NULL,
    created_at date NOT NULL
);

INSERT INTO customers
SELECT g,
       'Customer ' || g,
       'User' || g || '@Example.com',                                   -- mixed case on purpose
       c.country,
       c.country || '-city' || (1 + (g / 10) % 5),                      -- 5 cities per country: city implies country
       date '2020-01-01' + (g % 2000)
FROM generate_series(1, 100000) AS g,
     LATERAL (SELECT (ARRAY['PT','BR','US','ES','FR','DE','IT','UK','NL','IE'])[1 + g % 10] AS country) AS c;

-- autovacuum off on orders only for this lab, so we control VACUUM and ANALYZE ourselves
CREATE TABLE orders (
    id          bigint PRIMARY KEY,
    customer_id int NOT NULL REFERENCES customers (id),
    status      text NOT NULL,
    amount      numeric(10,2) NOT NULL,
    created_at  timestamptz NOT NULL,
    note        text
) WITH (autovacuum_enabled = false);

INSERT INTO orders
SELECT g,
       1 + (random() * 99999)::int,
       CASE WHEN g % 100 = 0 THEN 'pending'                             -- 1%
            WHEN g % 25  = 0 THEN 'cancelled'                           -- 3%
            ELSE 'delivered' END,                                       -- 96%
       round((random() * 500)::numeric, 2),
       timestamptz '2024-01-01' + random() * interval '730 days',
       repeat('x', 50)
FROM generate_series(1, 2000000) AS g;

ANALYZE customers;
ANALYZE orders;
