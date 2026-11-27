-- 01-schema.sql: documents + embedding queue + triggers that fill the queue
CREATE SCHEMA kb;

CREATE TABLE kb.documents (
    id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    title       text NOT NULL,
    content     text NOT NULL,
    embedding   vector(768),          -- NULL until the worker computes it
    embedded_at timestamptz           -- when the current embedding was computed
);

CREATE TABLE kb.embedding_queue (
    id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    doc_id      bigint      NOT NULL,                 -- the document to (re)embed
    enqueued_at timestamptz NOT NULL DEFAULT now(),
    attempts    int         NOT NULL DEFAULT 0,       -- failed tries so far
    last_error  text,
    next_try_at timestamptz NOT NULL DEFAULT now()    -- retry later after a failure
);

-- The trigger only writes a "to do" note. It never calls the model.
CREATE FUNCTION kb.enqueue_embedding() RETURNS trigger
LANGUAGE plpgsql AS 4267
BEGIN
    INSERT INTO kb.embedding_queue (doc_id) VALUES (NEW.id);
    RETURN NEW;
END;
$$;

-- New document: always needs an embedding
CREATE TRIGGER documents_enqueue_insert
    AFTER INSERT ON kb.documents
    FOR EACH ROW EXECUTE FUNCTION kb.enqueue_embedding();

-- Changed document: only when the CONTENT really changed
CREATE TRIGGER documents_enqueue_update
    AFTER UPDATE OF content ON kb.documents
    FOR EACH ROW
    WHEN (OLD.content IS DISTINCT FROM NEW.content)
    EXECUTE FUNCTION kb.enqueue_embedding();
