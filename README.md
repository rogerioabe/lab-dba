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
## Week 4 - Configuration and parameters
  - main memory parameters
  - pg_settings view 
  - create a bench environment for testing and measuring TPS
  - tuning memory parameters
## Week 5 - Backup and Restore
  - Backup tools: pg_dump, pg_dumpall and pg_basebackup
  - Restore tools: pg_restore
  - Restore files: recovery_signal 
  - restore_command for wal files
  - performing restore using dump
  - performing restore using physical backup
## Week 6 - Restore PITR 
  - main parameters
  - pgBackRest tool
  - stanza (catalog)
  - type of backup (full, diff and inc)
  - labs
## Week 7 - Physical Replication (Streaming), Standby and Failover
  - Concept
  - Slots
  - Walsender and Walreceiver
  - Primary and Replica
  - Mains views: pg_stat_replication, pg_replication_slots and pg_stat_wal_receiver
  - pg_is_in_recovery() 
  - creating replica using pg_basebackup -R and pgbackrest --stanza=... --type=standby restore
  - failover and switchover using SELECT pg_promote();    
  - /var/lib/pgsql/18/data/standby.signal for standby
  - parameters primary_conninfo and primary_slot_name on standby
  - labs 
## Week 8 - Logical Replication and Patroni 
  - Logical replica Architecture
  - Subscrptions 
  - Replications rules (DDL, sequence, large objects and mview not replicated) 
  - Patroni Architecture 
  - Patroni Instalation and Configuration
  - Patroni Failover and Switchover
