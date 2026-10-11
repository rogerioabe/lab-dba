#########################################
## Architeture Concepts
#########################################
Shared memory:
=============
shared_buffers: buffer cache for 8 KB data pages.
wal_buffers: WAL staging area before it is flushed to disk.
Lock table, transaction state and other control structures.

Per-backend memory:
==================
work_mem: memory allocated per sort or hash operation. A complex query can use several multiples of work_mem, and that multiplies again by the number of connections. Getting this sizing wrong is a classic cause of OOM.
maintenance_work_mem: used by VACUUM, CREATE INDEX and similar maintenance operations.
temp_buffers: used for temporary tables.

Process				What it does									Oracle equivalent
checkpointer			Flushes all dirty pages at each checkpoint and sets the recovery start point	CKPT + DBWn at checkpoint
background writer		Writes dirty pages out incrementally so backends can find clean buffers		DBWn
walwriter			Flushes WAL buffers to disk							LGWR
autovacuum launcher + workers	Automatic VACUUM and ANALYZE							— (plus the automatic stats-gathering job)
archiver			Archives completed WAL segments (requires archive_mode=on)			ARCn
walsender / walreceiver		Ship and receive WAL for streaming replication					Data Guard redo transport processes
io workers (PG 18)		Asynchronous read I/O								—
logger				Writes the text server log (logging_collector)					alert log

Physical storage
================
The data directory is $PGDATA (in this lab, /var/lib/pgsql/18/data). Key contents:

Item			Contents											Oracle equivalent
base/			One subdirectory per database, named after the database OID					datafiles
global/			Cluster-wide catalogs, such as pg_database							SYSTEM tablespace (partially)
pg_wal/			WAL segments	online redo logs
pg_xact/		Commit status of each transaction (formerly pg_clog)						— (in Oracle this lives in the undo segment header)
pg_tblspc/		Symbolic links to tablespaces									—
postgresql.auto.conf	Settings written by ALTER SYSTEM								spfile
postmaster.pid		Lock file holding the PID, port and shared memory segment ID; absent when the server is down	—

-- check which parameter demands restart, reload or is online to persist the change
lab=> SELECT name, context FROM pg_settings
WHERE name IN ('listen_addresses','shared_buffers','work_mem','log_min_duration_statement');
            name            |  context
----------------------------+------------
 listen_addresses           | postmaster
 log_min_duration_statement | superuser
 shared_buffers             | postmaster
 work_mem                   | user
(4 rows)

postmaster - Restart
sighup - Reload (SELECT pg_reload_conf(); ou systemctl reload) - eg. pg_hba.conf, log_min_duration_statement
user/superuser - online 

-- check pending changes 
lab=> SELECT name, setting, pending_restart FROM pg_settings WHERE pending_restart;
 name | setting | pending_restart
------+---------+-----------------
(0 rows)

-- check current connection 
lab=> \conninfo
      Connection Information
      Parameter       |   Value
----------------------+-----------
 Database             | lab
 Client User          | dba
 Host                 | db1
 Host Address         | 127.0.1.1
 Server Port          | 5432
 Options              |
 Protocol Version     | 3.0
 Password Used        | true
 GSSAPI Authenticated | false
 Backend PID          | 4586
 SSL Connection       | false
 Superuser            | off
 Hot Standby          | off
(13 rows)


-- connections methods in pg_hba.conf 
Método			Verifica
trust			nada (perigoso)
peer			usuário do Linux = role (só conexão local)
scram-sha-256	senha com hash forte (padrão atual)
md5				senha (legado, sendo descontinuado)
reject			bloqueia




SELECT name, context FROM pg_settings WHERE name IN ('listen_addresses','shared_buffers','work_mem','log_min_duration_statement');"
ALTER SYSTEM SET shared_buffers = '256MB';"
SELECT pg_reload_conf();"
SELECT name, setting, pending_restart FROM pg_settings WHERE name = 'shared_buffers';"
gresql-18
SHOW shared_buffers;"

####################################
## TABLE CONCEPTS 
####################################
-- table concepts: each file table has 01GB. A new file with 01GB will be created when its limit hits.
-- Huge columns is managed in TOAST tables, similar to LOB objects
-- Index has its own file as well

-- check table physical path 
SELECT pg_relation_filepath('table_name');

 pg_relation_filepath
----------------------
 base/16390/16391
(1 row)

[postgres@db1 16390]$ ll /var/lib/pgsql/18/data/base/16390/16391*
-rw-------. 1 postgres postgres  8192 Oct 10 13:54 /var/lib/pgsql/18/data/base/16390/16391
-rw-------. 1 postgres postgres 24576 Oct 10 13:54 /var/lib/pgsql/18/data/base/16390/16391_fsm <== free space map
-rw-------. 1 postgres postgres  8192 Oct 10 13:54 /var/lib/pgsql/18/data/base/16390/16391_vm <== visibility map (dead tuples)


-- Onde está fisicamente a tabela t do laboratório?
SELECT pg_relation_filepath('t');            -- algo como base/16384/16390
SELECT oid, datname FROM pg_database;        -- confere o OID da pasta em base/
SELECT pg_relation_size('t'), pg_total_relation_size('t');

-- Processos com nome
SELECT pid, backend_type FROM pg_stat_activity;

-- Checkpoints e WAL
SELECT * FROM pg_stat_checkpointer;
SELECT pg_walfile_name(pg_current_wal_lsn());



