-- Lesson 39 dataset: 100k vectors (768 dims) around 1,000 random centers, plus 20 test queries.
CREATE EXTENSION IF NOT EXISTS vector;
DROP TABLE IF EXISTS items, queries, centroids;

-- 1,000 random "topics"
CREATE TABLE centroids AS
SELECT c AS id,
       (SELECT array_agg(random() * 2 - 1) FROM generate_series(1, 768) WHERE c > 0)::vector(768) AS v
FROM generate_series(1, 1000) AS c;

-- 100k items: each one is a topic center plus noise; category is a random filter column (1..100)
CREATE TABLE items AS
SELECT g AS id,
       1 + (random() * 99)::int AS category,
       (SELECT array_agg(x + (random() - 0.5) * 2) FROM unnest(c.v::real[]) AS x)::vector(768) AS embedding
FROM generate_series(1, 100000) AS g
JOIN centroids c ON c.id = 1 + (g * 7) % 1000;

ALTER TABLE items ADD PRIMARY KEY (id);

-- 20 test questions: existing items with some extra noise
CREATE TABLE queries AS
SELECT i.id,
       (SELECT array_agg(x + (random() - 0.5)) FROM unnest(i.embedding::real[]) AS x)::vector(768) AS v
FROM items i
WHERE i.id % 5000 = 0;
