-- try-as-acme.sql: the application acting for tenant acme
SET app.tenant = 'acme';

\echo '--- vector search'
SELECT tenant, title, round((embedding <=> '[1,0,0]')::numeric, 4) AS distance
FROM rag.documents ORDER BY embedding <=> '[1,0,0]' LIMIT 2;

\echo '--- asking explicitly for globex'
SELECT count(*) FROM rag.documents WHERE tenant = 'globex';

\echo '--- writing into globex'
INSERT INTO rag.documents (tenant, title, embedding)
VALUES ('globex', 'planted by acme', '[1,0,0]');

\echo '--- writing into acme'
INSERT INTO rag.documents (tenant, title, embedding)
VALUES ('acme', 'acme: new doc', '[0.5,0.5,0]');
