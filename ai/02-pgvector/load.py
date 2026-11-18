"""Embed each line of sentences.txt and store it in PostgreSQL (Python version of load.sh)."""
import psycopg

from embedding import MODEL, get_embedding

with open("sentences.txt") as f:
    sentences = [line.strip() for line in f if line.strip()]

with psycopg.connect("dbname=aidb") as conn:
    conn.execute("TRUNCATE sentences RESTART IDENTITY")
    for sentence in sentences:
        conn.execute(
            "INSERT INTO sentences (content, model, embedding) VALUES (%s, %s, %s::vector)",
            (sentence, MODEL, get_embedding(sentence)),
        )
        print(f"loaded: {sentence}")
# leaving the "with" block commits; an error inside it rolls everything back
