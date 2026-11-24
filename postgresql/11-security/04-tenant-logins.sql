-- 04-tenant-logins.sql: one login per tenant + the map "login -> tenant"
CREATE ROLE tenants    NOLOGIN;                  -- neutral group: holds the shared privileges
CREATE ROLE acme_app   LOGIN IN ROLE tenants;    -- the acme application logs in with this
CREATE ROLE globex_app LOGIN IN ROLE tenants;    -- the globex application logs in with this

GRANT CONNECT ON DATABASE ragdb TO tenants;
GRANT USAGE ON SCHEMA rag TO tenants;
GRANT SELECT, INSERT ON rag.documents TO tenants;   -- same table for everyone; RLS picks the rows

SET ROLE rag_owner;
CREATE TABLE rag.tenant_members (                -- which login belongs to which tenant
    role_name name NOT NULL PRIMARY KEY,
    tenant    text NOT NULL
);
RESET ROLE;
INSERT INTO rag.tenant_members VALUES ('acme_app', 'acme'), ('globex_app', 'globex');
