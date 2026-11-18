"""PostgreSQL health check: a quick report of one server, for a DBA.

Usage: python healthcheck.py [database]       (default: perfdb)
Exit code: 0 = OK, 1 = warning found, 2 = could not connect.
"""
import sys

import psycopg
from psycopg.rows import dict_row

CACHE_HIT_WARNING = 95.0   # percent
CONNECTIONS_WARNING = 80.0  # percent of max_connections


def run(conn, sql):
    """Run a query and return all rows as dictionaries."""
    with conn.cursor(row_factory=dict_row) as cur:
        cur.execute(sql)
        return cur.fetchall()

def main():
    dbname = sys.argv[1] if len(sys.argv) > 1 else "perfdb"
    warnings = []

    try:
        conn = psycopg.connect(dbname=dbname, connect_timeout=5)
    except psycopg.OperationalError as e:
        print(f"CRITICAL: cannot connect to {dbname}: {e}")
        return 2

    with conn:
        #1. Server
        info = run(conn, """
           SELECT current_setting('server_version') AS version,
                  date_trunc('second', now() - pg_postmaster_start_time()) AS uptime,
                  pg_is_in_recovery() AS is_replica
        """)[0]
        print(f"== Server: PostgreSQL {info['version']}, up {info['uptime']}, "
              f"{'replica' if info['is_replica'] else 'primary'}")

        #2. Connections
        conns = run(conn, """
            SELECT count(*) AS used,
                   current_setting('max_connections')::int AS max
            FROM pg_stat_activity
        """)[0]
        pct = 100.0 * conns["used"] / conns["max"]
        print(f"== Connections: {conns['used']} of {conns['max']} ({pct:.0f}%)")
        if pct > CONNECTIONS_WARNING:
            warnings.append(f"connections at {pct:.0f}%")

        for row in run(conn, """
            SELECT coalesce(state, 'background') AS state, count(*) AS n
            FROM pg_stat_activity GROUP BY 1 ORDER BY 2 DESC
        """):
            print(f"   {row['state']:<20} {row['n']}")

        # 3. Databases and cache hit ratio
        print("== Databases")
        for row in run(conn, """
            SELECT datname,
                   pg_size_pretty(pg_database_size(datname)) AS size,
                   round(100.0 * blks_hit / nullif(blks_hit + blks_read, 0), 1) AS cache_hit
            FROM pg_stat_database
            WHERE datname IS NOT NULL AND datname NOT LIKE 'template%'
            ORDER BY pg_database_size(datname) DESC
        """):
            print(f"   {row['datname']:<20} {row['size']:>10}   cache hit {row['cache_hit']}%")
            if row["cache_hit"] is not None and row["cache_hit"] < CACHE_HIT_WARNING:
                warnings.append(f"cache hit {row['cache_hit']}% in {row['datname']}")

        # 4. Largest tables in this database
        print(f"== Largest tables in {dbname}")
        for row in run(conn, """
            SELECT relname, n_live_tup, n_dead_tup,
                   pg_size_pretty(pg_total_relation_size(relid)) AS size,
                   last_autovacuum
            FROM pg_stat_user_tables
            ORDER BY pg_total_relation_size(relid) DESC
            LIMIT 5
        """):
            print(f"   {row['relname']:<20} {row['size']:>10}   live {row['n_live_tup']:>10}"
                  f"   dead {row['n_dead_tup']:>8}   last autovacuum {row['last_autovacuum']}")

        # 5. Indexes never used (ignoring PK / UNIQUE)
        unused = run(conn, """
            SELECT s.relname, s.indexrelname,
                   pg_size_pretty(pg_relation_size(s.indexrelid)) AS size
            FROM pg_stat_user_indexes s
            JOIN pg_index i ON i.indexrelid = s.indexrelid
            WHERE s.idx_scan = 0 AND NOT i.indisunique
            ORDER BY pg_relation_size(s.indexrelid) DESC
        """)
        print(f"== Unused indexes: {len(unused)}")
        for row in unused:
            print(f"   {row['relname']}.{row['indexrelname']} ({row['size']})")

    conn.close()

    if warnings:
        print("WARNING: " + "; ".join(warnings))
        return 1
    print("OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
