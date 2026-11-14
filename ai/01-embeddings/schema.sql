-- Sentences and their embeddings, stored as a plain float8 array (no pgvector yet).
CREATE TABLE IF NOT EXISTS sentences (
    id        serial PRIMARY KEY,
    content   text NOT NULL,
    model     text NOT NULL DEFAULT 'nomic-embed-text',
    embedding float8[] NOT NULL
);

-- Cosine similarity between two vectors: 1 = same direction, 0 = unrelated.
CREATE OR REPLACE FUNCTION cosine_similarity(a float8[], b float8[])
RETURNS float8
LANGUAGE sql IMMUTABLE
AS $$
    SELECT sum(x * y) / (sqrt(sum(x * x)) * sqrt(sum(y * y)))
    FROM unnest(a, b) AS t(x, y)
$$;
