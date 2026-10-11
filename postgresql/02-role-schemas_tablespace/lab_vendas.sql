-- database, schema, roles, logins

sudo -iu postgres psql

CREATE DATABASE vendas;
\c vendas

-- grupos (sem LOGIN)
CREATE ROLE app_leitura;
CREATE ROLE app_escrita;

-- usuários (com LOGIN)
CREATE ROLE ana   LOGIN PASSWORD 'ana123';
CREATE ROLE bruno LOGIN PASSWORD 'bruno123';
GRANT app_leitura TO ana;
GRANT app_escrita TO bruno;

-- schema com dono
CREATE SCHEMA loja AUTHORIZATION bruno;

GRANT CONNECT ON DATABASE vendas TO app_leitura, app_escrita;
GRANT USAGE ON SCHEMA loja TO app_leitura;

\c "host=localhost dbname=vendas user=bruno"
CREATE TABLE loja.pedidos (id serial PRIMARY KEY, valor numeric);
INSERT INTO loja.pedidos (valor) VALUES (100), (250);
GRANT SELECT ON loja.pedidos TO app_leitura;

\c "host=localhost dbname=vendas user=ana"
SELECT * FROM loja.pedidos;     -- funciona
INSERT INTO loja.pedidos (valor) VALUES (1);   -- deve falhar

-- grant para permitir que novas tabelas sejam lidas por outros users
\c "host=localhost dbname=vendas user=bruno"
ALTER DEFAULT PRIVILEGES IN SCHEMA loja GRANT SELECT ON TABLES TO app_leitura;


-- TABLESPACE 

-- criar diretorio
sudo mkdir -p /pgdata/ts_rapida && sudo chown postgres: /pgdata/ts_rapida

-- criar tablespace 
CREATE TABLESPACE ts_rapida LOCATION '/pgdata/ts_rapida';

-- alterar a tablespace da tabela
ALTER TABLE loja.pedidos SET TABLESPACE ts_rapida;
SELECT pg_relation_filepath('loja.pedidos');

-- checar o link simbolico 
sudo ls -l /var/lib/pgsql/18/data/pg_tblspc/


\du          -- roles e quem pertence a quem
                              List of roles
  Role name  |                         Attributes
-------------+------------------------------------------------------------
 ana         |
 app_escrita | Cannot login
 app_leitura | Cannot login
 bruno       |
 dba         | Create role, Create DB
 postgres    | Superuser, Create role, Create DB, Replication, Bypass RLS


\dn+         -- schemas, donos e permissões
                                       List of schemas
  Name  |       Owner       |           Access privileges            |      Description
--------+-------------------+----------------------------------------+------------------------
 loja   | bruno             | bruno=UC/bruno                        +|
        |                   | app_leitura=U/bruno                    |
 public | pg_database_owner | pg_database_owner=UC/pg_database_owner+| standard public schema
        |                   | =U/pg_database_owner                   |
(2 rows)

\dp loja.*   -- permissões por tabela
                                     Access privileges
 Schema |      Name       |   Type   |  Access privileges   | Column privileges | Policies
--------+-----------------+----------+----------------------+-------------------+----------
 loja   | clientes        | table    |                      |                   |
 loja   | clientes_id_seq | sequence |                      |                   |
 loja   | pedidos         | table    | bruno=arwdDxtm/bruno+|                   |
        |                 |          | app_leitura=r/bruno  |                   |
 loja   | pedidos_id_seq  | sequence |                      |                   |
 loja   | teste           | table    | app_leitura=r/bruno +|                   |
        |                 |          | bruno=arwdDxtm/bruno |                   |
 loja   | teste_id_seq    | sequence |                      |                   |
(6 rows)

\db          -- tablespaces
            List of tablespaces
    Name    |  Owner   |     Location
------------+----------+-------------------
 pg_default | postgres |
 pg_global  | postgres |
 ts_rapida  | postgres | /pgdata/ts_rapida
(3 rows)

