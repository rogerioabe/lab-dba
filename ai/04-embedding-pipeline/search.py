"""search.py: semantic search over kb.documents, flagging results whose embedding is stale."""
import sys

import psycopg

from worker import embed, to_vector      # reuse the same model call as the worker

question = sys.argv[1]
q = to_vector(embed(question))

with psycopg.connect("dbname=aidb") as conn:
    rows = conn.execute(
        """
        SELECT d.title,
               round((d.embedding <=> %s::vector)::numeric, 4) AS distance,
               EXISTS (SELECT 1 FROM kb.embedding_queue q WHERE q.doc_id = d.id) AS stale
        FROM kb.documents d
        WHERE d.embedding IS NOT NULL
        ORDER BY d.embedding <=> %s::vector
        LIMIT 3
        """,
        [q, q],
    ).fetchall()

for title, distance, stale in rows:
    flag = "  <-- embedding is OUT OF DATE" if stale else ""
    print(f"{distance}  {title}{flag}")
