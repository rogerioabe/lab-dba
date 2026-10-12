########################################################
## BACKUP AND RESTORE USING
########################################################

-- create the directories
[vagrant@db1 ~]$ sudo mkdir -p /backup /pgarchive
[vagrant@db1 ~]$ sudo chown postgres: /backup /pgarchive

-- dump database 
[vagrant@db1 backup]$ sudo -iu postgres pg_dump -Fc -d vendas -f /backup/vendas.dump
[vagrant@db1 backup]$ ll /backup/vendas.dump
-rw-r--r--. 1 postgres postgres 7066 Oct 12 18:11 /backup/vendas.dump
[vagrant@db1 backup]$ vi /backup/vendas.dump

-- restoring the dump 
[vagrant@db1 backup]$ sudo -iu postgres pg_restore -l /backup/vendas.dump | head -30
;
; Archive created at 2026-10-12 18:11:01 WEST
;     dbname: vendas
;     TOC Entries: 30
;     Compression: gzip
;     Dump Version: 1.16-0
;     Format: CUSTOM
;     Integer: 4 bytes
;     Offset: 8 bytes
;     Dumped from database version: 18.6
;     Dumped by pg_dump version: 18.6
;
;
; Selected TOC Entries:
;
6; 2615 16407 SCHEMA - loja bruno
3430; 0 0 ACL - SCHEMA loja bruno
223; 1259 16419 TABLE loja clientes bruno
222; 1259 16418 SEQUENCE loja clientes_id_seq bruno
3431; 0 0 SEQUENCE OWNED BY loja clientes_id_seq bruno
221; 1259 16409 TABLE loja pedidos bruno
3432; 0 0 ACL loja TABLE pedidos bruno
220; 1259 16408 SEQUENCE loja pedidos_id_seq bruno
3433; 0 0 SEQUENCE OWNED BY loja pedidos_id_seq bruno
225; 1259 16428 TABLE loja teste bruno
3434; 0 0 ACL loja TABLE teste bruno
224; 1259 16427 SEQUENCE loja teste_id_seq bruno
3435; 0 0 SEQUENCE OWNED BY loja teste_id_seq bruno
3264; 2604 16422 DEFAULT loja clientes id bruno
3263; 2604 16412 DEFAULT loja pedidos id bruno

-- restoring dump to another database 
[vagrant@db1 backup]$ sudo -iu postgres createdb vendas_restore

[vagrant@db1 backup]$ sudo -iu postgres pg_restore -d vendas_restore /backup/vendas.dump
[vagrant@db1 backup]$ sudo -iu postgres psql -h db1
Password for user postgres:
psql (18.6)
Type "help" for help.

postgres=# \c vendas_restore
You are now connected to database "vendas_restore" as user "postgres".
vendas_restore=# select tablename from pg_tables where schemaname='loja';
 tablename
-----------
 clientes
 pedidos
 teste
(3 rows)

vendas_restore=# \dt lojas.*
Did not find any tables named "lojas.*".
vendas_restore=# \dt loja.*
          List of tables
 Schema |   Name   | Type  | Owner
--------+----------+-------+-------
 loja   | clientes | table | bruno
 loja   | pedidos  | table | bruno
 loja   | teste    | table | bruno
(3 rows)


-- exporting the roles and tablespace definition
[vagrant@db1 backup]$ sudo -iu postgres pg_dumpall --globals-only -f /backup/globais.sql
[vagrant@db1 backup]$ grep -E "CREATE ROLE|TABLESPACE" /backup/globais.sql
CREATE ROLE ana;
CREATE ROLE app_escrita;
CREATE ROLE app_leitura;
CREATE ROLE bruno;
CREATE ROLE dba;
CREATE ROLE postgres;
CREATE TABLESPACE ts_rapida OWNER postgres LOCATION '/pgdata/ts_rapida';

-- restoring a single table 
[vagrant@db1 backup]$ sudo -iu postgres psql -d vendas_restore -c "DROP TABLE loja.pedidos;"
DROP TABLE
[vagrant@db1 backup]$ sudo -iu postgres pg_restore -d vendas_restore -t pedidos -n loja /backup/vendas.dump
[vagrant@db1 backup]$ sudo -iu postgres psql -d vendas_restore -c "SELECT * FROM loja.pedidos;"
 id | valor
----+-------
  1 |   100
  2 |   250
(2 rows)


## Physical backup 
1- WAL activate 

[vagrant@db1 backup]$ sudo -iu postgres psql
psql (18.6)
Type "help" for help.
postgres=# ALTER SYSTEM SET archive_mode = 'on';
ALTER SYSTEM
postgres=# ALTER SYSTEM SET archive_command = 'test ! -f /pgarchive/%f && cp %p /pgarchive/%f';
ALTER SYSTEM

-- restarting the cluster and generating wal file 
[vagrant@db1 backup]$ sudo systemctl restart postgresql-18

[vagrant@db1 backup]$ sudo -iu postgres psql -c "SELECT pg_switch_wal();" -- equal ALTER SYSTEM SWITCH LOGFILE;
 pg_switch_wal
---------------
 0/E30E76E8
(1 row)

[vagrant@db1 backup]$ sleep 2
[vagrant@db1 backup]$ ls -l /pgarchive
total 16384
-rw-------. 1 postgres postgres 16777216 Oct 12 18:36 0000000100000000000000E3

[vagrant@db1 backup]$ sudo -iu postgres psql -c "SELECT archived_count, last_archived_wal, failed_count FROM pg_stat_archiver;"
 archived_count |    last_archived_wal     | failed_count
----------------+--------------------------+--------------
              1 | 0000000100000000000000E3 |            0
(1 row)


-- performing a database backup 
[vagrant@db1 backup]$ sudo -iu postgres pg_basebackup -D /backup/base_01 -Ft -z -P -X stream -c fast
924014/924014 kB (100%), 2/2 tablespaces

-- about the options 
-Ft -z: formato tar, compactado;
-P: mostra o progresso;
-X stream: inclui o WAL gerado durante o backup, para ele ser consistente por si só;
-c fast: força um checkpoint imediato, em vez de esperar o próximo.

[vagrant@db1 backup]$ sudo -iu postgres ls -l /backup/base_01/
total 82624
-rw-------. 1 postgres postgres      486 Oct 12 18:38 16433.tar.gz -- tablespace bkp
-rw-------. 1 postgres postgres   319825 Oct 12 18:39 backup_manifest  -- backup catalog
-rw-------. 1 postgres postgres 84258714 Oct 12 18:39 base.tar.gz -- database
-rw-------. 1 postgres postgres    17114 Oct 12 18:39 pg_wal.tar.gz -- wall files

-- validating the backup set 
[vagrant@db1 backup]$ sudo -iu postgres /usr/pgsql-18/bin/pg_verifybackup -n /backup/base_01
backup successfully verified

-- validating restore after backup by using wal files 
[vagrant@db1 backup]$ sudo -iu postgres psql -d lab -c "CREATE TABLE depois_do_backup AS SELECT now() AS criado_em;"
SELECT 1
[vagrant@db1 backup]$ sudo -iu postgres psql -c "SELECT pg_switch_wal();"
 pg_switch_wal
---------------
 0/E6017688
 
 [vagrant@db1 backup]$ ls -ls /pgarchive
total 65540
16384 -rw-------. 1 postgres postgres 16777216 Oct 12 18:36 0000000100000000000000E3
16384 -rw-------. 1 postgres postgres 16777216 Oct 12 18:38 0000000100000000000000E4
16384 -rw-------. 1 postgres postgres 16777216 Oct 12 18:39 0000000100000000000000E5
    4 -rw-------. 1 postgres postgres      343 Oct 12 18:39 0000000100000000000000E5.00000028.backup
16384 -rw-------. 1 postgres postgres 16777216 Oct 12 18:44 0000000100000000000000E6

-- simulating data loss
[vagrant@db1 backup]$ sudo systemctl stop postgresql-18
[vagrant@db1 backup]$ sudo mv /var/lib/pgsql/18/data /var/lib/pgsql/18/data_antigo

-- restoring the data from backup 
[vagrant@db1 backup]$ sudo -iu postgres tar -xzf /backup/base_01/base.tar.gz -C /var/lib/pgsql/18/data
[vagrant@db1 backup]$ sudo -iu postgres tar -xzf /backup/base_01/pg_wal.tar.gz -C /var/lib/pgsql/18/data/pg_wal

[vagrant@db1 backup]$ echo "restore_command = 'cp /pgarchive/%f %p'" | sudo -iu postgres tee -a /var/lib/pgsql/18/data/postgresql.auto.conf
restore_command = 'cp /pgarchive/%f %p' -- tell where the wal files are
[vagrant@db1 backup]$ sudo -iu postgres touch /var/lib/pgsql/18/data/recovery.signal -- sign the postgre to enter in recovery mode 

-- starting the database
[vagrant@db1 backup]$ sudo systemctl start postgresql-18

-- checking the log
sudo tail -40 /var/lib/pgsql/18/data/log/postgresql-Mon.log
2026-10-12 18:49:12.215 WEST [22637] @ LOG:  starting backup recovery with redo LSN 0/E5000028, checkpoint LSN 0/E5000080, on timeline ID 1
2026-10-12 18:49:12.251 WEST [22637] @ LOG:  restored log file "0000000100000000000000E5" from archive
2026-10-12 18:49:12.280 WEST [22637] @ LOG:  starting archive recovery
2026-10-12 18:49:12.322 WEST [22637] @ LOG:  redo starts at 0/E5000028
2026-10-12 18:49:12.349 WEST [22637] @ LOG:  restored log file "0000000100000000000000E6" from archive
2026-10-12 18:49:12.395 WEST [22637] @ LOG:  restored log file "0000000100000000000000E7" from archive
cp: cannot stat '/pgarchive/0000000100000000000000E8': No such file or directory
2026-10-12 18:49:12.433 WEST [22637] @ LOG:  completed backup recovery with redo LSN 0/E5000028 and end LSN 0/E5000158
2026-10-12 18:49:12.433 WEST [22637] @ LOG:  consistent recovery state reached at 0/E5000158
2026-10-12 18:49:12.433 WEST [22630] @ LOG:  database system is ready to accept read-only connections
cp: cannot stat '/pgarchive/0000000100000000000000E8': No such file or directory
2026-10-12 18:49:12.480 WEST [22637] @ LOG:  redo done at 0/E7000060 system usage: CPU: user: 0.00 s, system: 0.00 s, elapsed: 0.15 s
2026-10-12 18:49:12.481 WEST [22637] @ LOG:  last completed transaction was at log time 2026-10-12 18:44:50.837713+01
2026-10-12 18:49:12.521 WEST [22637] @ LOG:  restored log file "0000000100000000000000E7" from archive
cp: cannot stat '/pgarchive/00000002.history': No such file or directory
2026-10-12 18:49:12.599 WEST [22637] @ LOG:  selected new timeline ID: 2
cp: cannot stat '/pgarchive/00000001.history': No such file or directory
2026-10-12 18:49:12.713 WEST [22637] @ LOG:  archive recovery complete
2026-10-12 18:49:12.727 WEST [22635] @ LOG:  checkpoint starting: end-of-recovery immediate wait
2026-10-12 18:49:12.841 WEST [22635] @ LOG:  checkpoint complete: wrote 18 buffers (0.0%), wrote 3 SLRU buffers; 0 WAL file(s) added, 0 removed, 3 recycled; write=0.028 s, sync=0.037 s, total=0.127 s; sync files=17, longest=0.008 s, average=0.003 s; distance=49152 kB, estimate=49152 kB; lsn=0/E8000028, redo lsn=0/E8000028
2026-10-12 18:49:12.852 WEST [22630] @ LOG:  database system is ready to accept connections

-- validating the restore process 
[vagrant@db1 backup]$ sudo -iu postgres psql -d lab -c "SELECT * FROM depois_do_backup;"
           criado_em
-------------------------------
 2026-10-12 18:44:50.827606+01
(1 row)

[vagrant@db1 backup]$ sudo -iu postgres psql -c "SELECT timeline_id FROM pg_control_checkpoint();"
 timeline_id
-------------
           2  -- equal resetlogs (from 1 to 2)
(1 row)

[vagrant@db1 backup]$ sudo -iu postgres ls /var/lib/pgsql/18/data/recovery.signal
ls: cannot access '/var/lib/pgsql/18/data/recovery.signal': No such file or directory -- expected result. The Postgres drops the file after restoring

