# Lab DBA — PostgreSQL, MySQL, Ansible

## Week 1 — PostgreSQL 18 - connect to ctl
- db1: Manual Installation (PGDG), Cluster creation, Network
- db2/db3: binaries by Ansible (pg-binarios.yml), for replicas without initdb
- Architeture notes: (processes, shared_buffers, pg_wal...)
- login dba  
## Week 2 roles, schemas, grants and tablespaces
- MCVV tables
  - controled inside tables
  - updates and deletes creates a new row inside the table, changing its ctid.
## Week 3 - MVCC, VACUUM, Autovacuum and bloat
  - Investigating fragmentation by using the following queries:
    SELECT * FROM pgstattuple('bloat');
    SELECT pg_size_pretty(table_len)        AS tamanho_total,
       tuple_count                      AS linhas_vivas,
       pg_size_pretty(tuple_len)        AS espaco_vivas,
       round(tuple_percent::numeric, 1) AS pct_vivas,
       dead_tuple_count                 AS linhas_mortas,
       round(dead_tuple_percent::numeric, 1) AS pct_mortas,
       pg_size_pretty(free_space)       AS espaco_livre,
       round(free_percent::numeric, 1)  AS pct_livre
    FROM pgstattuple('bloat');
    SELECT * FROM pgstattuple_approx('bloat');
    SELECT avg_leaf_density, leaf_fragmentation FROM pgstatindex('bloat_pkey');
