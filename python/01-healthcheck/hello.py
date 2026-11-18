"""First contact: connect to PostgreSQL and run one query."""
import psycopg

with psycopg.connect("dbname=perfdb") as conn:
    row = conn.execute("SELECT current_user, current_database(), version()").fetchone()
    print(row)
    user, database, version = row
    print(f"Connected as {user} to {database}")
    print(version)
