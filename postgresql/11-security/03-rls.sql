-- 03-rls.sql: each tenant sees only its own rows
ALTER TABLE rag.documents ENABLE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation ON rag.documents
    USING      (tenant = current_setting('app.tenant', true))   -- which rows you can SEE
    WITH CHECK (tenant = current_setting('app.tenant', true));  -- which rows you can WRITE
