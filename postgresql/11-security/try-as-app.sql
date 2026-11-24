-- try-as-app.sql: what can the application role do?
SET ROLE app_user;
SELECT count(*) FROM rag.documents;          -- allowed
DELETE FROM rag.documents WHERE id = 1;      -- no DELETE privilege
CREATE TABLE rag.evil (x int);               -- no CREATE on schema rag
CREATE TABLE public.evil (x int);            -- no CREATE on public (PG15+)
DROP TABLE rag.documents;                    -- only the owner can drop
