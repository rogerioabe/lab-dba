-- 05-rls-by-login.sql: VERSION 2 (the one we keep): the tenant comes from who logged in

-- Returns the tenant of the login that opened the session.
-- SECURITY DEFINER: runs as its owner (rag_owner), so tenants never need to read the map
-- (and cannot list the other customers). search_path is pinned against hijacking.
SET ROLE rag_owner;
CREATE FUNCTION rag.my_tenants() RETURNS SETOF text
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path = pg_catalog, rag
AS $$ 
    SELECT tenant FROM rag.tenant_members WHERE role_name = session_user
$$;
RESET ROLE;

DROP POLICY tenant_isolation ON rag.documents;

CREATE POLICY tenant_by_login ON rag.documents
    USING      (tenant IN (SELECT rag.my_tenants()))   -- which rows you can SEE
    WITH CHECK (tenant IN (SELECT rag.my_tenants()));  -- which rows you can WRITE
