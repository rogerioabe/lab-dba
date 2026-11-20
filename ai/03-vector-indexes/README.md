# AI 03 — Vector indexes: HNSW vs IVFFlat, recall and tuning

100k vectors (768 dims, 1,000 synthetic topics) on the `ai` VM. Exact search vs approximate
indexes, with recall measured against the exact answer for 20 test queries.

## Files

| File | Purpose |
| ---- | ------- |
| `setup.sql` | 1,000 random centers, 100k noisy vectors around them, 20 test queries |
| `recall.py` | recall@10 and latency for several `hnsw.ef_search` / `ivfflat.probes` values |

## Results

| | Exact (Seq Scan) | HNSW | IVFFlat (lists = 100) |
| - | ---------------- | ---- | --------------------- |
| Build time | — | ~60 s (64 MB `maintenance_work_mem`: slower, with a NOTICE) | ~4 s |
| Index size | — | ~390 MB (`halfvec`: ~195 MB) | ~390 MB |
| Top-10 latency | ~600 ms | ~1–3 ms | ~2–24 ms |
| Recall@10 | 1.00 | 0.59 / 0.85 / **1.00** (ef_search 10 / 20 / 40) | 0.14 → 0.79 (probes 1 → 20) |

## Lessons

- The index only works for `ORDER BY <indexed expr> <operator of its opclass> <vector> LIMIT k`.
  A different operator, `ORDER BY similarity DESC` or no `LIMIT` silently fall back to a Seq Scan.
- `hnsw.ef_search` is the recall/latency knob; recall must be measured against an exact search.
- Build HNSW with enough `maintenance_work_mem` (session-level `SET`) and parallel workers.
- Filters are applied after the index scan (post-filtering): with a 5% filter, a `LIMIT 10`
  query returned only 4 rows. `hnsw.iterative_scan = relaxed_order` (pgvector 0.8) fixes it;
  very selective filters make the planner pick an exact search instead.
- An HNSW index on `embedding::halfvec(768)` is half the size with the same top 10.
- IVFFlat builds much faster but needs many probes for good recall on spread-out data.
