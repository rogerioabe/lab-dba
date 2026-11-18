# Python 01 — PostgreSQL health check

A DBA health check in Python with psycopg 3: server version and uptime, connections by
state, database sizes with cache hit ratio, largest tables with dead tuples and last
autovacuum, and indexes never used (ignoring PK / UNIQUE).

## Run

```bash
python3.11 -m venv ~/venvs/dba && source ~/venvs/dba/bin/activate
pip install -r requirements.txt
python healthcheck.py perfdb
```

Exit codes, for cron or monitoring: `0` OK, `1` warning (cache hit below 95% or
connections above 80% of `max_connections`), `2` cannot connect.

## Design choices

- Connects through libpq like `psql` (peer auth, `.pgpass`, `PG*` variables): no password in the code.
- Query parameters always go as `%s`, never inside f-strings (SQL injection).
- `with conn:` wraps the queries in one transaction; `connect_timeout` avoids hanging.
- Small `run()` helper returns rows as dictionaries (`dict_row`).
