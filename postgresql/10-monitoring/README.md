# 10 — Monitoring: pg_stat_statements, auto_explain, waits and locks

A simulated application (pgbench) on the lesson 09 `perfdb` database, on the `ai` VM:
find the query that costs the server most, see its real plan in the log, sample wait
events, and reproduce three lock incidents.

## Files

| File | Purpose |
| ---- | ------- |
| `app.sql` | pgbench script: three fast queries from lesson 09 (weight 20) |
| `report.sql` | pgbench script: daily sales report on a random day (weight 1) |

```bash
pgbench -n -c 4 -T 30 -f app.sql@20 -f report.sql@1 perfdb
```

## Results

| | Before | After `CREATE INDEX ON orders (created_at)` |
| - | ------ | ------------------------------------------- |
| Throughput | ~75 tps | ~2,500 tps |
| Report latency | ~1,000 ms | ~14 ms |
| Report share of total server time (`pg_stat_statements`) | ~100% with ~5% of the calls | — |

## Incidents reproduced

| Incident | What `pg_stat_activity` showed | Fix | Prevention |
| -------- | ------------------------------ | --- | ---------- |
| Row lock | writer waiting on `Lock:transactionid`, blocked by an `idle in transaction` session | `pg_terminate_backend(<blocker>)` | `idle_in_transaction_session_timeout` |
| DDL lock queue | `ALTER TABLE` waiting behind an open transaction, and every `SELECT` waiting behind the `ALTER` | end the blocking transaction | `SET lock_timeout` before any DDL |
| Deadlock | `ERROR: deadlock detected` after `deadlock_timeout` (1 s), details in the log | automatic (one transaction aborted) | update rows in a consistent order |

## Lessons

- Rank queries by **total** time, not mean time: 5% of the calls used ~100% of the server.
- `pg_stat_statements` normalizes queries (`$1`, `$2`) and needs `shared_preload_libraries` + restart.
- `auto_explain` logs the real plan of slow queries without anyone running EXPLAIN.
- Sampling `wait_event_type` / `wait_event` over time is a hand-made ASH: CPU, IO, Lock, LWLock.
- `pg_blocking_pids()` gives the chain; the root is the session blocked by nobody.
- A waiting `ALTER TABLE` blocks every later query on the table, even `SELECT`s.
