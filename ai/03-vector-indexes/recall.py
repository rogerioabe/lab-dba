"""Measure recall and latency of an approximate (index) vector search.

For each test query, compares the top 10 from the index with the exact top 10
(index disabled), for several values of the index search parameter.

Usage: python recall.py hnsw      (tries hnsw.ef_search = 10, 20, 40, 100, 200)
       python recall.py ivfflat   (tries ivfflat.probes = 1, 2, 5, 10, 20)
"""
import sys
import time

import psycopg

K = 10
SETTINGS = {
    "hnsw": ("hnsw.ef_search", [10, 20, 40, 100, 200]),
    "ivfflat": ("ivfflat.probes", [1, 2, 5, 10, 20]),
}
SEARCH = "SELECT id FROM items ORDER BY embedding <=> %s LIMIT %s"


def top_ids(conn, vector):
    """Run the search and return the set of ids and the time in ms."""
    start = time.perf_counter()
    rows = conn.execute(SEARCH, (vector, K)).fetchall()
    elapsed_ms = (time.perf_counter() - start) * 1000
    return {row[0] for row in rows}, elapsed_ms


def main():
    parameter, values = SETTINGS[sys.argv[1]]

    with psycopg.connect("dbname=aidb", autocommit=True) as conn:
        queries = conn.execute("SELECT v::text FROM queries ORDER BY id").fetchall()

        # 1. Exact answers: index disabled, so the planner does a Seq Scan
        conn.execute("SET enable_indexscan = off")
        exact = [top_ids(conn, q[0])[0] for q in queries]
        conn.execute("RESET enable_indexscan")

        # 2. Approximate answers, for each value of the parameter
        print(f"{parameter:>16} | recall@{K} | avg ms")
        for value in values:
            conn.execute(f"SET {parameter} = {value}")
            hits, total_ms = 0, 0.0
            for q, truth in zip(queries, exact):
                found, ms = top_ids(conn, q[0])
                hits += len(found & truth)
                total_ms += ms
            recall = hits / (K * len(queries))
            print(f"{value:>16} | {recall:>9.2f} | {total_ms / len(queries):>6.1f}")


if __name__ == "__main__":
    main()
