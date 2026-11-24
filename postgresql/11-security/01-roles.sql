-- 01-roles.sql: database, roles and the schema owner
CREATE DATABASE ragdb;
CREATE ROLE rag_owner NOLOGIN;          -- owns the objects, nobody logs in as it
CREATE ROLE app_user  LOGIN;            -- the RAG application
CREATE ROLE analyst   LOGIN;            -- read-only reporting
\c ragdb
CREATE EXTENSION IF NOT EXISTS vector;
CREATE SCHEMA rag AUTHORIZATION rag_owner;
SET ROLE rag_owner;
CREATE TABLE rag.documents (
    id        bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tenant    text      NOT NULL,
    title     text      NOT NULL,
    embedding vector(3) NOT NULL
);
RESET ROLE;
INSERT INTO rag.documents (tenant, title, embedding) VALUES
  ('acme',   'acme: how to tune VACUUM',         '[0.90, 0.10, 0.00]'),
  ('acme',   'acme: backup policy',              '[0.20, 0.90, 0.10]'),
  ('acme',   'acme: holiday calendar',           '[0.00, 0.10, 0.90]'),
  ('globex', 'globex: CONFIDENTIAL merger plan', '[0.99, 0.01, 0.00]'),
  ('globex', 'globex: salary table',             '[0.10, 0.80, 0.20]');
