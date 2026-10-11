###########################################
## ROLES, SCHEMAS, GRANTS AND TABLESPACES
###########################################

In PostgresSQL CREATE USER = CREATE ROLE + LOGIN
Oracle			PostgreSQL
CREATE USER		CREATE ROLE ... LOGIN (ou CREATE USER, que é um apelido)
CREATE ROLE		CREATE ROLE sem LOGIN, usado como grupo
GRANT role TO user	GRANT grupo TO usuario
SYSDBA			atributo SUPERUSER
CREATE SESSION		atributo LOGIN + permissão no pg_hba.conf

Objects Hierarchy
=================
Cluster (Instance)
 └─ Database        ← isolated; JOIN between the databases isn't allowed
     └─ Schema      ← namespace, same as Oracle, but not as USERNAME 
         └─ Tables, indexes, views, functions...

USER <> SCHEMA

Para um usuário ler uma tabela, ele precisa de três coisas:
To an user be able to read a table, it must have the 3 things below:
CONNECT on database;
USAGE on schema;
SELECT in the tabela.

Tablespaces
============
In PostgreSQL, a tablespace is only a directory. It doesn't have datafile, quotas and autoextend. It's usefull to split data in other disks.

