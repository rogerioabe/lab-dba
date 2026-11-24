-- 02-privileges.sql: least privilege for the application and the analyst
REVOKE ALL ON DATABASE ragdb FROM PUBLIC;          -- nobody connects by default
GRANT CONNECT ON DATABASE ragdb TO app_user, analyst;

GRANT USAGE ON SCHEMA rag TO app_user;
GRANT SELECT, INSERT ON rag.documents TO app_user; -- no UPDATE, DELETE, TRUNCATE

GRANT pg_read_all_data TO analyst;                 -- predefined role: read everything
