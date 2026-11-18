"""Rank the stored sentences by similarity to a question (Python version of search.sh).

Usage: python search.py "your question"
"""
import sys

import psycopg

from embedding import get_embedding

question = sys.argv[1]
question_embedding = get_embedding(question)

with psycopg.connect("dbname=aidb") as conn:
    rows = conn.execute(
        """
        SELECT round((1 - (embedding <=> %s::vector))::numeric, 3) AS similarity, content
        FROM sentences
        ORDER BY embedding <=>  %s::vector
        LIMIT %s
        """,
        (question_embedding, question_embedding, 3),
    ).fetchall()

print(f"Question: {question}")
for similarity, content in rows:
    print(f"  {similarity}  {content}")
