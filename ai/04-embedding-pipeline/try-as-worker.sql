    -- try-as-worker.sql: what the worker must NOT be able to do
    SELECT title FROM kb.documents LIMIT 1;               -- title is not granted
    UPDATE kb.documents SET content = 'x' WHERE id = 1;   -- content is not writable
    DELETE FROM kb.documents WHERE id = 1;                -- no DELETE on documents
