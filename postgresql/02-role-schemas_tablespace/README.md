###########################################
## ROLES, SCHEMAS, GRANTS AND TABLESPACES
###########################################

No PostgreSQL não existe separação entre CREATE USER e CREATE ROLE: tudo é role. O que muda é o atributo LOGIN.

Oracle			PostgreSQL
CREATE USER		CREATE ROLE ... LOGIN (ou CREATE USER, que é um apelido)
CREATE ROLE		CREATE ROLE sem LOGIN, usado como grupo
GRANT role TO user	GRANT grupo TO usuario
SYSDBA			atributo SUPERUSER
CREATE SESSION		atributo LOGIN + permissão no pg_hba.conf

Hierarquia de objetos
Cluster (instância)
 └─ Database        ← isolado; não há JOIN entre databases
     └─ Schema      ← namespace, como no Oracle, mas sem estar preso a um usuário
         └─ Tabela, índice, view, função...

USER <> SCHEMA

Para um usuário ler uma tabela, ele precisa de três coisas:

CONNECT on database;
USAGE on schema;
SELECT in the tabela.

Tablespaces
============
No PostgreSQL, uma tablespace é apenas um diretório. Não tem datafiles, cotas nem autoextend, e é usada principalmente para colocar dados em outro disco.

