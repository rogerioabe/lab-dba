    -- 03-worker-role.sql: the worker can only do its job (lesson 15: least privilege)
    CREATE ROLE embed_worker LOGIN;

    GRANT CONNECT ON DATABASE aidb TO embed_worker;
    GRANT USAGE ON SCHEMA kb TO embed_worker;

    -- the queue: read jobs, record failures, remove finished jobs
    GRANT SELECT, UPDATE, DELETE ON kb.embedding_queue TO embed_worker;

    -- the documents: read only id + content, write only the embedding columns
    GRANT SELECT (id, content)            ON kb.documents TO embed_worker;
    GRANT UPDATE (embedding, embedded_at) ON kb.documents TO embed_worker;
