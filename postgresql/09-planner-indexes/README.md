# 09 — Planner, EXPLAIN ANALYZE, index types and statistics

Five slow queries on a 2-million-row `orders` table, each fixed with a different technique,
measured with `EXPLAIN (ANALYZE, BUFFERS)` before and after. Runs on the standalone `ai` VM
(PostgreSQL 18), database `perfdb`.

## Dataset

`setup.sql` creates 100k `customers` and 2M `orders` with only primary keys. The data is
skewed on purpose: mixed-case e-mails, 96% / 3% / 1% order statuses, and a city that
always implies its country.

```bash
createdb perfdb
psql -d perfdb -f setup.sql
```

## Results

| # | Problem | Fix | Before | After |
| - | ------- | --- | ------ | ----- |
| 1 | Foreign key without an index: Seq Scan on 2M rows | B-tree on `orders(customer_id)` | 285 ms | 0.3 ms |
| 2 | `lower(email)` cannot use the index on `email` | Expression index on `lower(email)` | 26 ms | 0.05 ms |
| 3 | Latest 10 `pending` orders: scan + sort | Partial index `(created_at) WHERE status = 'pending'`, read backward, no sort | 340 ms | 0.4 ms |
| 4 | Composite index with the range column first | `(customer_id, created_at)`: equality first, range second | 17 ms | 0.4 ms |
| 5 | Correlated columns: city implies country, estimate 10x too low | `CREATE STATISTICS (dependencies)` + `random_page_cost = 1.1` for SSD | wrong plan | right plan, 160 ms |
| + | Index Only Scan blocked on a never-vacuumed table | `VACUUM` sets the visibility map | 100 ms | 3 ms |

## Lessons

- PostgreSQL does not index foreign keys automatically.
- A function on a column hides the column from its index; index the expression instead.
- With skewed data, the planner uses `pg_stats.most_common_vals` and correctly keeps a
  Seq Scan for the frequent value. A partial index covers the rare value at a fraction of the size.
- Composite indexes: equality columns first, range columns last. An index on `(a, b)`
  also serves filters on `a` alone, so a separate index on `a` is redundant.
- "Index Cond" with both columns does not mean an efficient scan: compare the buffers.
- The planner needs right row estimates (statistics, extended statistics for correlated
  columns) and right hardware costs (`random_page_cost`). Fixing only one can make the
  plan worse.
- Index Only Scan depends on the visibility map, which VACUUM maintains.
- No hints in PostgreSQL: fix statistics, costs and indexes; use `enable_*` only to diagnose.
