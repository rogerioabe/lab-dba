# 04 — Embedding pipeline: keep vectors in sync when data changes

A trigger writes a "to do" note to a queue table in the same transaction as the change;
a Python worker takes jobs with `FOR UPDATE SKIP LOCKED`, calls Ollama and saves the vector.

| Piece | File | Why |
|---|---|---|
| Table + queue + triggers | `01-schema.sql` | nothing is lost (same transaction), nothing is forgotten (any write path), writers never wait for the model |
| Sample data | `02-seed.sql` | small knowledge base |
| Worker role | `03-worker-role.sql` | column privileges: reads `id, content`, writes only `embedding, embedded_at` |
| Worker | `worker.py` | one job per transaction, `SKIP LOCKED`, retries with backoff, dead letters after 5 attempts |
| Search | `search.py` | flags results whose embedding is out of date |
| Monitoring | `monitor.sql` | pending, failing, dead, oldest job age |

## Design decisions

- Triggers fire only when `content` really changes (`UPDATE OF content` + `WHEN (OLD.content IS DISTINCT FROM NEW.content)`).
- One queue row per change, no dedup: writers never block on a job a worker holds; a change made while a worker is embedding produces a new job that fixes the vector.
- No FK from queue to documents: a delete never waits for a locked job; the worker drops jobs whose document is gone.
- The old vector is kept while a new one is pending (search flags it), instead of the document disappearing from search.
- pgai Vectorizer was the planned alternative, but the project is no longer maintained (February 2026); this pipeline uses only native PostgreSQL features.

## Results

- 6 inserts -> 6 jobs; title change -> 0 jobs; same content -> 0 jobs; real content change -> 1 job.
- Two terminals: `SKIP LOCKED` returned the next job immediately; plain `FOR UPDATE` waited.
- Two workers split the queue with no job processed twice.
- Ollama stopped: job kept with `attempts = 1` and the error, retried after the backoff, then processed.
- Search before the worker ran: the changed document was flagged OUT OF DATE and ranked poorly; after: first place.
