# Lab DBA — PostgreSQL, MySQL, Ansible

## Week 1 — PostgreSQL 18 - connect to ctl
- db1: instalação manual (PGDG), cluster criado, acesso pela rede 192.168.56.0/24
- db2/db3: binários via Ansible (pg-binarios.yml), sem initdb — serão réplicas
- Notas de arquitetura: (processos, shared_buffers padrão, pg_wal...)
- login dba criado 
- Cada sessão no banco gera um processo no OS. Para muitas conexões, o pgBouncer é uma opção para shared connections
- o Shared buffer ocupa cerca de 25-40% da RAM pq o postgres depende do cache de paginas do Linux para leituras
## Week 2 roles, schemas, grants and tablespaces
- MCVV de tabelas
  - é controlado por tabela
  - update e deletes geram uma nova linha na tabela, alterado seu ctid. O commando VACCUM apaga as linhas mortas
## Week 3 - MVCC, VACUUM, Autovacuum and bloat
