    -- 06-audit.sql: session audit (classes) + object audit (reads of rag.documents)
    CREATE EXTENSION IF NOT EXISTS pgaudit;

    -- object audit: every statement that uses a privilege the "auditor" role also has
    CREATE ROLE auditor NOLOGIN;
    GRANT SELECT ON rag.documents TO auditor;       -- => every read of documents is logged
    ALTER DATABASE ragdb SET pgaudit.role = 'auditor';

    -- session audit: writes, DDL and role/privilege changes, for everyone
    ALTER DATABASE ragdb SET pgaudit.log = 'write, ddl, role';
    ALTER DATABASE ragdb SET pgaudit.log_parameter = on;
