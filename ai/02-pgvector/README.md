# AI 02 — pgvector: types, operators, exact search

Second lab of the AI layer, on the `ai` VM: install pgvector, migrate the lesson 01 table
from `float8[]` to `vector(768)`, and replace the hand-written cosine function with the
`<=>` operator.

## Files

| File | Purpose |
| ---- | ------- |
| `pgvector.sql` | extension, operators on toy vectors, migration, exact search |
| `embedding.py` | `get_embedding(text)` through the Ollama API |
| `load.py` | loads `sentences.txt` into the `vector(768)` column, in one transaction |
| `search.py` | ranks sentences with `embedding <=> question` |

## Install

```bash
sudo dnf install -y pgvector_18          # package: on every server
psql -d aidb -c "CREATE EXTENSION vector;"   # objects: in every database that uses it
```

## Results

| | `float8[]` + SQL function (lesson 01) | `vector(768)` + `<=>` |
| - | ----------------------------------- | --------------------- |
| Bytes per 768-dim embedding | ~6,164 | ~3,076 (`halfvec`: ~1,544) |
| 20k vectors, table size | ~159 MB | ~80 MB |
| 20k vectors, exact top-5 search | ~3,200 ms | ~100 ms |
| Same top results | yes | yes |

## Lessons

- An extension is a package on every server plus `CREATE EXTENSION` in every database.
  pgvector needs no `shared_preload_libraries` and no restart.
- Operators return distances: smaller is closer, so `ORDER BY embedding <=> q` without `DESC`.
  Cosine similarity is `1 - (a <=> b)`. `<#>` returns the negative inner product.
- Cosine ignores vector length and compares direction only; the inner product grows with length.
- `ALTER COLUMN ... TYPE vector(768) USING ...` rewrites the table under an ACCESS EXCLUSIVE
  lock: fine for a lab, use a new column and batch backfill in production.
- Exact search is still a sequential scan: 30x faster than SQL math, but linear in the
  number of rows. Approximate indexes (HNSW, IVFFlat) come next.
