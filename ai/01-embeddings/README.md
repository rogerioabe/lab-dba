# AI 01 — Embeddings and semantic search in plain SQL

First lab of the AI layer, on the standalone `ai` VM (PostgreSQL 18 + Ollama): generate
text embeddings with a local model (`nomic-embed-text`, 768 dimensions) and find sentences
by **meaning** with a cosine similarity function written in SQL, before using pgvector.

## Files

| File | Purpose |
| ---- | ------- |
| `sentences.txt` | 8 sample sentences: 4 about PostgreSQL, 4 about other topics |
| `schema.sql` | `sentences` table (embedding as `float8[]`) and `cosine_similarity()` |
| `load.sh` | embeds each sentence through the Ollama API and inserts it |
| `search.sh` | embeds a question and ranks the sentences by cosine similarity |

## Run (on the `ai` VM)

```bash
psql -d aidb -f schema.sql
./load.sh
./search.sh "How does the database clean up old rows?"
```

`OLLAMA_URL` defaults to `http://localhost:11434`.

## What it shows

- The question shares no words with "VACUUM removes dead tuples", yet that sentence ranks
  first: embeddings capture meaning, not keywords.
- Each embedding is 768 `float8` values, about 6 kB per row, above the ~2 kB TOAST threshold.
- `EXPLAIN ANALYZE` shows a sequential scan that computes the similarity for every row.
  This exact search does not scale, which is what pgvector and its HNSW / IVFFlat
  indexes solve in the next labs.

## Key concepts

| Concept | In one line |
| ------- | ----------- |
| Embedding | fixed-size vector of floats that represents the meaning of a text |
| Same model | documents and questions must be embedded by the same model; a new model means re-embedding everything |
| Cosine similarity | angle between two vectors: 1 = same meaning, close to 0 = unrelated |
| Exact vs approximate search | exact (kNN) scans every row; approximate (ANN) uses an index and trades some recall for speed |
| RAG | retrieve the closest chunks with SQL, add them to the prompt, let the LLM answer from them |

## Python version (lesson 19)

| File | Purpose |
| ---- | ------- |
| `embedding.py` | `get_embedding(text)`: calls the Ollama API with `requests` |
| `load.py` | loads `sentences.txt` in a single transaction (all or nothing) |
| `search.py` | ranks the sentences by cosine similarity to a question |
| `requirements.txt` | `psycopg[binary]`, `requests` |

```bash
pip install -r requirements.txt
python load.py
python search.py "How does the database clean up old rows?"
```

Compared with the bash version, psycopg sends the embedding as a parameter (a Python list
becomes a `float8[]`), and the whole load is one transaction: if Ollama fails halfway,
nothing is half-loaded.

> **Note:** lesson 02 migrates the `sentences.embedding` column to `vector(768)`. After that,
> the scripts in this folder (which use `cosine_similarity(float8[], float8[])`) no longer
> work; use the versions in [`ai/02-pgvector`](../02-pgvector/).
