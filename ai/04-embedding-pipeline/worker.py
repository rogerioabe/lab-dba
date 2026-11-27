"""worker.py: keeps kb.documents.embedding in sync with kb.documents.content.

Takes one job at a time from kb.embedding_queue, asks Ollama for the embedding
and saves it. Several copies can run at the same time (FOR UPDATE SKIP LOCKED).
"""
import os
import time

import psycopg
import requests

OLLAMA_URL = "http://localhost:11434/api/embed"
MODEL = "nomic-embed-text"
MAX_ATTEMPTS = 5
WORKER = f"worker-{os.getpid()}"          # a name to tell the copies apart in the output


def embed(text):
    """Ask Ollama for the embedding of one text. Returns a list of 768 floats."""
    response = requests.post(OLLAMA_URL, json={"model": MODEL, "input": text}, timeout=60)
    response.raise_for_status()
    return response.json()["embeddings"][0]


def to_vector(values):
    """Python list -> pgvector text format: '[0.1,0.2,...]'."""
    return "[" + ",".join(str(v) for v in values) + "]"


def process_one(conn):
    """Process one job. Returns False when there is nothing to do."""
    with conn.transaction():
        job = conn.execute(
            """
            SELECT id, doc_id
            FROM kb.embedding_queue
            WHERE next_try_at <= now() AND attempts < %s
            ORDER BY id
            LIMIT 1
            FOR UPDATE SKIP LOCKED
            """,
            [MAX_ATTEMPTS],
        ).fetchone()
        if job is None:
            return False
        job_id, doc_id = job

        row = conn.execute("SELECT content FROM kb.documents WHERE id = %s", [doc_id]).fetchone()
        if row is None:                     # the document was deleted meanwhile
            conn.execute("DELETE FROM kb.embedding_queue WHERE id = %s", [job_id])
            print(f"{WORKER}: job {job_id}: document {doc_id} no longer exists, job removed")
            return True

        try:
            vector = embed(row[0])
        except requests.RequestException as error:
            conn.execute(
                """
                UPDATE kb.embedding_queue
                SET attempts    = attempts + 1,
                    last_error  = %s,
                    next_try_at = now() + interval '10 seconds' * (attempts + 1)
                WHERE id = %s
                """,
                [str(error)[:200], job_id],
            )
            print(f"{WORKER}: job {job_id}: Ollama failed, will retry later ({error.__class__.__name__})")
            return True

        conn.execute(
            "UPDATE kb.documents SET embedding = %s::vector, embedded_at = now() WHERE id = %s",
            [to_vector(vector), doc_id],
        )
        conn.execute("DELETE FROM kb.embedding_queue WHERE id = %s", [job_id])
        print(f"{WORKER}: job {job_id}: document {doc_id} embedded")
        return True


def main():
    with psycopg.connect("service=embed_worker", autocommit=True) as conn:
        print(f"{WORKER}: started")
        while True:
            if not process_one(conn):
                time.sleep(2)               # queue empty: wait a little and look again


if __name__ == "__main__":
    main()
