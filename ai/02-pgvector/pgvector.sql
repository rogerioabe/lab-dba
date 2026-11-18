-- Lesson 38: pgvector basics on the aidb database (run with: psql -d aidb)

CREATE EXTENSION IF NOT EXISTS vector;

-- Operators on toy 2-D vectors: question [0.8,0], "VACUUM" [0.9,0.1], "cat" [0,0.9]
SELECT '[0.8,0.0]'::vector <=> '[0.9,0.1]'::vector       AS cosine_distance_vacuum,
       1 - ('[0.8,0.0]'::vector <=> '[0.9,0.1]'::vector) AS cosine_similarity_vacuum,
       1 - ('[0.8,0.0]'::vector <=> '[0.0,0.9]'::vector) AS cosine_similarity_cat,
       '[0.8,0.0]'::vector <#> '[0.9,0.1]'::vector       AS negative_inner_product;

-- Migrate the lesson 37 table from float8[] to vector(768)
ALTER TABLE sentences
  ALTER COLUMN embedding TYPE vector(768) USING embedding::vector(768);

-- Exact search: distance ascending, similarity = 1 - distance
SELECT round((1 - (embedding <=> (SELECT embedding FROM sentences WHERE id = 2)))::numeric, 3) AS similarity,
       content
FROM sentences
ORDER BY embedding <=> (SELECT embedding FROM sentences WHERE id = 2)
LIMIT 3;
