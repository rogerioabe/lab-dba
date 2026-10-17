####################################
## LAB - REPLICATION
####################################
-- cleaning the configuration files
[vagrant@db1 ~]$ sudo -iu postgres grep -nE "recovery_target|restore_command" /var/lib/pgsql/18/data/postgresql.auto.conf
sudo -iu postgres sed -i '/^recovery_target/d;/^restore_command/d' /var/lib/pgsql/18/data/postgresql.auto.conf
12:restore_command = 'cp /pgarchive/%f %p'
13:restore_command = 'cp /pgarchive/%f %p'
17:restore_command = 'pgbackrest --stanza=lab archive-get %f "%p"'
18:recovery_target_time = '2026-10-14 19:07:05+01'
19:recovery_target_action = 'promote'

-- creating the replicator role 
[vagrant@db1 ~]$ sudo -iu postgres psql <<'EOF'
CREATE ROLE replicador WITH REPLICATION LOGIN PASSWORD 'repl123';
ALTER SYSTEM SET cluster_name = 'db1';
SHOW max_wal_senders;
SHOW max_replication_slots;
EOF
CREATE ROLE
ALTER SYSTEM
 max_wal_senders
-----------------
 10
(1 row)

 max_replication_slots
-----------------------
 10
(1 row)

-- configurating the user replication into pg_hba.conf 
[vagrant@db1 ~]$ echo "host replication replicador 192.168.56.0/24 scram-sha-256" | sudo -iu postgres tee -a /var/lib/pgsql/18/data/pg_hba.conf
host replication replicador 192.168.56.0/24 scram-sha-256

-- restarting the cluster (because of cluster_name parameter changing)
[vagrant@db1 ~]$ sudo systemctl restart postgresql-18
[vagrant@db1 ~]$ sudo systemctl status postgresql-18
● postgresql-18.service - PostgreSQL 18 database server
     Loaded: loaded (/usr/lib/systemd/system/postgresql-18.service; enabled; preset: disabled)
     Active: active (running) since Fri 2026-10-16 11:27:21 WEST; 9s ago
       Docs: https://www.postgresql.org/docs/18/static/
    Process: 4735 ExecStartPre=/usr/pgsql-18/bin/postgresql-18-check-db-dir ${PGDATA} (code=exited, status=0/SUCCESS)
   Main PID: 4740 (postgres)
      Tasks: 11 (limit: 12306)
     Memory: 42.6M
        CPU: 520ms
     CGroup: /system.slice/postgresql-18.service
             ├─4740 /usr/pgsql-18/bin/postgres -D /var/lib/pgsql/18/data/
             ├─4741 "postgres: db1: logger "
             ├─4742 "postgres: db1: io worker 0"
             ├─4743 "postgres: db1: io worker 2"
             ├─4744 "postgres: db1: io worker 1"
             ├─4745 "postgres: db1: checkpointer "
             ├─4746 "postgres: db1: background writer "
             ├─4748 "postgres: db1: walwriter "
             ├─4749 "postgres: db1: autovacuum launcher "
             ├─4750 "postgres: db1: archiver "
             └─4751 "postgres: db1: logical replication launcher "

Oct 16 11:27:21 db1 systemd[1]: Starting PostgreSQL 18 database server...
Oct 16 11:27:21 db1 postgres[4740]: 2026-10-16 11:27:21.777 WEST [4740] @ LOG:  redirecting log output to logging collector process
Oct 16 11:27:21 db1 postgres[4740]: 2026-10-16 11:27:21.777 WEST [4740] @ HINT:  Future log output will appear in directory "log".
Oct 16 11:27:21 db1 systemd[1]: Started PostgreSQL 18 database server.

-- setting db2 

vagrant ssh db2 

-- senha do replicador para o usuário postgres do db2 (campo do banco = replication)
echo "db1:5432:replication:replicador:repl123" | sudo -iu postgres tee /var/lib/pgsql/.pgpass
db1:5432:replication:replicador:repl123

sudo -iu postgres chmod 600 /var/lib/pgsql/.pgpass

-- a tablespace precisa existir no mesmo caminho, vazia
sudo mkdir -p /pgdata/ts_rapida && sudo chown postgres: /pgdata/ts_rapida

-- o diretório de dados precisa estar vazio (o db2 só tem os binários)
sudo ls -A /var/lib/pgsql/18/data

-- restoring the backup in the replica 
sudo -iu postgres pg_basebackup -h db1 -U replicador -D /var/lib/pgsql/18/data \
  -X stream -C -S slot_db2 -R -P
924151/924151 kB (100%), 2/2 tablespaces

-- setting the cluster_name into the config file
[vagrant@db2 ~]$ echo "cluster_name = 'db2'" | sudo -iu postgres tee -a /var/lib/pgsql/18/data/postgresql.auto.conf
cluster_name = 'db2'

[vagrant@db2 ~]$ sudo -iu postgres ls -l /var/lib/pgsql/18/data/standby.signal
-rw-------. 1 postgres postgres 0 Oct 16 11:34 /var/lib/pgsql/18/data/standby.signal

-- checking the parameters
[vagrant@db2 ~]$ sudo -iu postgres grep -E "primary_conninfo|primary_slot_name" /var/lib/pgsql/18/data/postgresql.auto.conf
primary_conninfo = 'user=replicador passfile=''/var/lib/pgsql/.pgpass'' channel_binding=prefer host=db1 port=5432 sslmode=prefer sslnegotiation=postgres sslcompression=0 sslcertmode=allow sslsni=1 ssl_min_protocol_version=TLSv1.2 gssencmode=prefer krbsrvname=postgres gssdelegation=0 target_session_attrs=any load_balance_hosts=disable'
primary_slot_name = 'slot_db2'

-- starting up the replica 
[vagrant@db2 ~]$ sudo systemctl enable --now postgresql-18
Created symlink /etc/systemd/system/multi-user.target.wants/postgresql-18.service → /usr/lib/systemd/system/postgresql-18.service.

[vagrant@db2 ~]$ sudo tail -20 /var/lib/pgsql/18/data/log/postgresql-Fri.log
2026-10-16 11:27:21.851 WEST [4747] @ LOG:  database system was shut down at 2026-10-16 11:27:21 WEST
2026-10-16 11:27:21.866 WEST [4740] @ LOG:  database system is ready to accept connections
2026-10-16 11:33:46.926 WEST [4745] @ LOG:  checkpoint starting: force wait
2026-10-16 11:33:46.981 P00   INFO: archive-push command begin 2.59.3: [pg_wal/0000000400000000000000F4] --compress-type=zst --exec-id=4773-1df09c7f --log-level-console=info --pg1-path=/var/lib/pgsql/18/data --process-max=2 --repo1-path=/var/lib/pgbackrest --stanza=lab
2026-10-16 11:33:47.101 P00   INFO: pushed WAL file '0000000400000000000000F4' to the archive
2026-10-16 11:33:47.107 P00   INFO: archive-push command end: completed successfully (142ms)
2026-10-16 11:33:47.122 WEST [4745] @ LOG:  checkpoint complete: wrote 1 buffers (0.0%), wrote 3 SLRU buffers; 0 WAL file(s) added, 0 removed, 0 recycled; write=0.118 s, sync=0.031 s, total=0.196 s; sync files=3, longest=0.013 s, average=0.011 s; distance=16384 kB, estimate=16384 kB; lsn=0/F5000080, redo lsn=0/F5000028
2026-10-16 11:38:58.957 WEST [4699] @ LOG:  starting PostgreSQL 18.6 on x86_64-pc-linux-gnu, compiled by gcc (GCC) 11.5.0 20240719 (Red Hat 11.5.0-5), 64-bit
2026-10-16 11:38:58.959 WEST [4699] @ LOG:  listening on IPv4 address "0.0.0.0", port 5432
2026-10-16 11:38:58.959 WEST [4699] @ LOG:  listening on IPv6 address "::", port 5432
2026-10-16 11:38:58.974 WEST [4699] @ LOG:  listening on Unix socket "/run/postgresql/.s.PGSQL.5432"
2026-10-16 11:38:58.994 WEST [4699] @ LOG:  listening on Unix socket "/tmp/.s.PGSQL.5432"
2026-10-16 11:38:59.038 WEST [4706] @ LOG:  database system was interrupted; last known up at 2026-10-16 11:33:47 WEST
2026-10-16 11:39:03.351 WEST [4706] @ LOG:  starting backup recovery with redo LSN 0/F5000028, checkpoint LSN 0/F5000080, on timeline ID 4
2026-10-16 11:39:03.353 WEST [4706] @ LOG:  entering standby mode
2026-10-16 11:39:03.376 WEST [4706] @ LOG:  redo starts at 0/F5000028
2026-10-16 11:39:03.387 WEST [4706] @ LOG:  completed backup recovery with redo LSN 0/F5000028 and end LSN 0/F5000158
2026-10-16 11:39:03.388 WEST [4706] @ LOG:  consistent recovery state reached at 0/F5000158
2026-10-16 11:39:03.389 WEST [4699] @ LOG:  database system is ready to accept read-only connections
2026-10-16 11:39:03.638 WEST [4707] @ LOG:  started streaming WAL from primary at 0/F6000000 on timeline 4

-- monitoring primary 
[vagrant@db1 ~]$ sudo -iu postgres psql -x -c "SELECT application_name, client_addr, state, sent_lsn, replay_lsn, replay_lag, sync_state FROM pg_stat_replication;"
-[ RECORD 1 ]----+--------------
application_name | db2
client_addr      | 192.168.56.12
state            | streaming
sent_lsn         | 0/F6000060
replay_lsn       | 0/F6000060
replay_lag       |
sync_state       | async

[vagrant@db1 ~]$ sudo -iu postgres psql -c "SELECT slot_name, active, wal_status FROM pg_replication_slots;"
 slot_name | active | wal_status
-----------+--------+------------
 slot_db2  | t      | reserved
(1 row)


-- monitoring replica 
[vagrant@db2 ~]$ sudo -iu postgres psql -x -c "SELECT status, sender_host, slot_name, latest_end_lsn FROM pg_stat_wal_receiver;"
-[ RECORD 1 ]--+-----------
status         | streaming
sender_host    | db1
slot_name      | slot_db2
latest_end_lsn | 0/F6000060

[vagrant@db2 ~]$ sudo -iu postgres psql -c "SELECT pg_is_in_recovery(), pg_last_wal_replay_lsn(), pg_last_xact_replay_timestamp();"
 pg_is_in_recovery | pg_last_wal_replay_lsn | pg_last_xact_replay_timestamp
-------------------+------------------------+-------------------------------
 t                 | 0/F6000060             |
(1 row)

-- testing replication 
-- on primary 
[vagrant@db1 ~]$ sudo -iu postgres psql -d lab -c "CREATE TABLE replicada AS SELECT now() AS criado_em;"
SELECT 1

-- on replica
[vagrant@db2 ~]$ sudo -iu postgres psql -d lab -c "SELECT * FROM replicada;"
          criado_em
------------------------------
 2026-10-16 11:47:38.60826+01
(1 row)

[vagrant@db2 ~]$ sudo -iu postgres psql -d lab -c "INSERT INTO replicada VALUES (now());"
ERROR:  cannot execute INSERT in a read-only transaction
[vagrant@db2 ~]$

-- SIMULATING LAG SITUATION 

-- performing vacuum on primary
[vagrant@db1 ~]$ /usr/pgsql-18/bin/pgbench -h localhost -U dba -c 8 -j 2 -T 60 bench
Password:
pgbench (18.6)
starting vacuum...end.
transaction type: <builtin: TPC-B (sort of)>
scaling factor: 50
query mode: simple
number of clients: 8
number of threads: 2
maximum number of tries: 1
duration: 60 s
number of transactions actually processed: 7437
number of failed transactions: 0 (0.000%)
latency average = 64.425 ms
initial connection time = 169.301 ms
tps = 124.174572 (without initial connection time)

-- checking the lag in another session 
postgres=# SELECT application_name, write_lag, flush_lag, replay_lag,
       pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn)) AS atraso
FROM pg_stat_replication \watch 2
          Fri 16 Oct 2026 11:54:34 AM WEST (every 2s)

 application_name | write_lag | flush_lag | replay_lag | atraso
------------------+-----------+-----------+------------+--------
 db2              |           |           |            | 561 kB
(1 row)

                   Fri 16 Oct 2026 11:54:36 AM WEST (every 2s)

 application_name |    write_lag    |    flush_lag    |   replay_lag    | atraso
------------------+-----------------+-----------------+-----------------+---------
 db2              | 00:00:01.766476 | 00:00:01.766476 | 00:00:01.771578 | 2441 kB
(1 row)

                   Fri 16 Oct 2026 11:54:38 AM WEST (every 2s)

 application_name |    write_lag    |    flush_lag    |   replay_lag    | atraso
------------------+-----------------+-----------------+-----------------+---------
 db2              | 00:00:02.626842 | 00:00:02.719064 | 00:00:02.722148 | 3736 kB
(1 row)

                  Fri 16 Oct 2026 11:54:40 AM WEST (every 2s)

 application_name |   write_lag    |    flush_lag    |   replay_lag    | atraso
------------------+----------------+-----------------+-----------------+--------
 db2              | 00:00:00.01558 | 00:00:00.023312 | 00:00:00.023312 | 40 kB
(1 row)

                   Fri 16 Oct 2026 11:54:42 AM WEST (every 2s)

 application_name |    write_lag    |    flush_lag    |   replay_lag    | atraso
------------------+-----------------+-----------------+-----------------+--------
 db2              | 00:00:00.006319 | 00:00:00.006319 | 00:00:00.006319 | 24 kB
(1 row)

            Fri 16 Oct 2026 11:54:44 AM WEST (every 2s)

 application_name | write_lag | flush_lag | replay_lag |   atraso
------------------+-----------+-----------+------------+------------
 db2              |           |           |            | 9064 bytes
(1 row)

                   Fri 16 Oct 2026 11:54:46 AM WEST (every 2s)

 application_name |    write_lag    |    flush_lag    |   replay_lag    | atraso
------------------+-----------------+-----------------+-----------------+--------
 db2              | 00:00:00.020139 | 00:00:00.020139 | 00:00:00.529288 | 771 kB
(1 row)

                   Fri 16 Oct 2026 11:54:48 AM WEST (every 2s)

 application_name |    write_lag    |    flush_lag    |   replay_lag    | atraso
------------------+-----------------+-----------------+-----------------+--------
 db2              | 00:00:00.005747 | 00:00:00.018091 | 00:00:00.018091 | 16 kB
(1 row)

                  Fri 16 Oct 2026 11:54:50 AM WEST (every 2s)

 application_name |   write_lag    |   flush_lag    |   replay_lag    | atraso
------------------+----------------+----------------+-----------------+--------
 db2              | 00:00:00.01173 | 00:00:00.01173 | 00:00:00.027077 | 49 kB
(1 row)

                     Fri 16 Oct 2026 11:54:52 AM WEST (every 2s)

 application_name |    write_lag    |    flush_lag    |   replay_lag    |   atraso
------------------+-----------------+-----------------+-----------------+------------
 db2              | 00:00:00.017831 | 00:00:00.017841 | 00:00:00.017841 | 8656 bytes
(1 row)

                   Fri 16 Oct 2026 11:54:54 AM WEST (every 2s)

 application_name |    write_lag    |    flush_lag    |   replay_lag    | atraso
------------------+-----------------+-----------------+-----------------+--------
 db2              | 00:00:00.010323 | 00:00:00.010323 | 00:00:00.010323 | 41 kB
(1 row)

                   Fri 16 Oct 2026 11:54:56 AM WEST (every 2s)

 application_name |    write_lag    |    flush_lag    |   replay_lag    | atraso
------------------+-----------------+-----------------+-----------------+--------
 db2              | 00:00:00.014385 | 00:00:00.024491 | 00:00:00.024491 | 50 kB
(1 row)

                   Fri 16 Oct 2026 11:54:58 AM WEST (every 2s)

 application_name |    write_lag    |    flush_lag    |   replay_lag    | atraso
------------------+-----------------+-----------------+-----------------+--------
 db2              | 00:00:00.013372 | 00:00:00.013372 | 00:00:00.013372 | 74 kB
(1 row)

                   Fri 16 Oct 2026 11:55:00 AM WEST (every 2s)

 application_name |    write_lag    |    flush_lag    |   replay_lag    | atraso
------------------+-----------------+-----------------+-----------------+---------
 db2              | 00:00:00.006102 | 00:00:00.012834 | 00:00:00.012834 | 0 bytes
(1 row)

                   Fri 16 Oct 2026 11:55:02 AM WEST (every 2s)

 application_name |    write_lag    |    flush_lag    |   replay_lag    | atraso
------------------+-----------------+-----------------+-----------------+--------
 db2              | 00:00:00.013664 | 00:00:00.013664 | 00:00:00.013664 | 63 kB
(1 row)

                  Fri 16 Oct 2026 11:55:04 AM WEST (every 2s)

 application_name |    write_lag    |   flush_lag    |   replay_lag   | atraso
------------------+-----------------+----------------+----------------+--------
 db2              | 00:00:00.015963 | 00:00:00.03565 | 00:00:00.03565 | 26 kB
(1 row)

                   Fri 16 Oct 2026 11:55:06 AM WEST (every 2s)

 application_name |    write_lag    |    flush_lag    |   replay_lag    | atraso
------------------+-----------------+-----------------+-----------------+--------
 db2              | 00:00:00.017258 | 00:00:00.017258 | 00:00:00.017258 | 16 kB
(1 row)

                     Fri 16 Oct 2026 11:55:08 AM WEST (every 2s)

 application_name |    write_lag    |    flush_lag    |   replay_lag    |   atraso
------------------+-----------------+-----------------+-----------------+------------
 db2              | 00:00:00.006159 | 00:00:00.012117 | 00:00:00.012117 | 8720 bytes
(1 row)

                  Fri 16 Oct 2026 11:55:10 AM WEST (every 2s)

 application_name |    write_lag    |   flush_lag    |   replay_lag    | atraso
------------------+-----------------+----------------+-----------------+--------
 db2              | 00:00:00.057978 | 00:00:00.05798 | 00:00:00.057983 | 261 kB
(1 row)

                   Fri 16 Oct 2026 11:55:12 AM WEST (every 2s)

 application_name |    write_lag    |    flush_lag    |   replay_lag    | atraso
------------------+-----------------+-----------------+-----------------+--------
 db2              | 00:00:00.008383 | 00:00:00.641059 | 00:00:00.641059 | 987 kB
(1 row)

                  Fri 16 Oct 2026 11:55:14 AM WEST (every 2s)

 application_name |    write_lag    |   flush_lag    |   replay_lag   | atraso
------------------+-----------------+----------------+----------------+---------
 db2              | 00:00:00.013478 | 00:00:00.01348 | 00:00:00.01348 | 0 bytes
(1 row)

                   Fri 16 Oct 2026 11:55:16 AM WEST (every 2s)

 application_name |    write_lag    |    flush_lag    |   replay_lag   | atraso
------------------+-----------------+-----------------+----------------+---------
 db2              | 00:00:00.007971 | 00:00:00.010574 | 00:00:00.01058 | 0 bytes
(1 row)

          Fri 16 Oct 2026 11:55:18 AM WEST (every 2s)

 application_name | write_lag | flush_lag | replay_lag | atraso
------------------+-----------+-----------+------------+--------
 db2              |           |           |            | 70 kB
(1 row)

                   Fri 16 Oct 2026 11:55:20 AM WEST (every 2s)

 application_name |    write_lag    |    flush_lag    |   replay_lag    | atraso
------------------+-----------------+-----------------+-----------------+--------
 db2              | 00:00:00.006795 | 00:00:00.020484 | 00:00:00.020484 | 26 kB
(1 row)

          Fri 16 Oct 2026 11:55:22 AM WEST (every 2s)

 application_name | write_lag | flush_lag | replay_lag | atraso
------------------+-----------+-----------+------------+--------
 db2              |           |           |            | 17 kB
(1 row)

                    Fri 16 Oct 2026 11:55:24 AM WEST (every 2s)

 application_name |    write_lag    |    flush_lag    |   replay_lag    |  atraso
------------------+-----------------+-----------------+-----------------+-----------
 db2              | 00:00:00.002006 | 00:00:00.010277 | 00:00:00.010277 | 304 bytes
(1 row)

                  Fri 16 Oct 2026 11:55:26 AM WEST (every 2s)

 application_name |    write_lag    |   flush_lag    |   replay_lag   | atraso
------------------+-----------------+----------------+----------------+--------
 db2              | 00:00:00.012129 | 00:00:00.03049 | 00:00:00.03049 | 58 kB
(1 row)

                   Fri 16 Oct 2026 11:55:28 AM WEST (every 2s)

 application_name |    write_lag    |    flush_lag    |   replay_lag    | atraso
------------------+-----------------+-----------------+-----------------+--------
 db2              | 00:00:00.009273 | 00:00:00.014487 | 00:00:00.014487 | 24 kB
(1 row)

                     Fri 16 Oct 2026 11:55:30 AM WEST (every 2s)

 application_name |    write_lag    |    flush_lag    |   replay_lag    |   atraso
------------------+-----------------+-----------------+-----------------+------------
 db2              | 00:00:00.021312 | 00:00:00.021312 | 00:00:00.021312 | 8872 bytes
(1 row)

           Fri 16 Oct 2026 11:55:32 AM WEST (every 2s)

 application_name | write_lag | flush_lag | replay_lag | atraso
------------------+-----------+-----------+------------+---------
 db2              |           |           |            | 0 bytes
(1 row)

           Fri 16 Oct 2026 11:55:34 AM WEST (every 2s)

 application_name | write_lag | flush_lag | replay_lag | atraso
------------------+-----------+-----------+------------+---------
 db2              |           |           |            | 0 bytes
(1 row)


-- SIMULATING QUERY CONFLICT 
-- performing the query on replica 
lab=# BEGIN ISOLATION LEVEL REPEATABLE READ;
BEGIN
lab=*# SELECT count(*) FROM bloat;
  count
---------
 1000000
 
 -- performing an update on primary 
 [vagrant@db1 ~]$ sudo -iu postgres psql -d lab -c "UPDATE bloat SET v = v || 'c' WHERE id <= 5000;"
UPDATE 5000
[vagrant@db1 ~]$ VACUUM (VERBOSE) bloat;
-bash: syntax error near unexpected token `VERBOSE'
[vagrant@db1 ~]$ sudo -iu postgres psql -d lab -c "VACUUM (VERBOSE) bloat;"
INFO:  vacuuming "lab.public.bloat"
INFO:  finished vacuuming "lab.public.bloat": index scans: 0
pages: 0 removed, 9440 remain, 143 scanned (1.51% of total), 0 eagerly scanned
tuples: 5000 removed, 995001 remain, 0 are dead but not yet removable
removable cutoff: 163111, which was 0 XIDs old when operation ended
new relfrozenxid: 163110, which is 1 XIDs ahead of previous value
frozen: 0 pages from table (0.00% of total) had 0 tuples frozen
visibility map: 47 pages set all-visible, 0 pages set all-frozen (0 were all-visible)
index scan bypassed: 96 pages from table (1.02% of total) have 9978 dead item identifiers
avg read rate: 0.000 MB/s, avg write rate: 0.990 MB/s
buffer usage: 247 hits, 0 reads, 1 dirtied
WAL usage: 96 records, 1 full page images, 21156 bytes, 0 buffers full
system usage: CPU: user: 0.00 s, system: 0.00 s, elapsed: 0.00 s
INFO:  vacuuming "lab.pg_toast.pg_toast_16448"
INFO:  finished vacuuming "lab.pg_toast.pg_toast_16448": index scans: 0
pages: 0 removed, 0 remain, 0 scanned (100.00% of total), 0 eagerly scanned
tuples: 0 removed, 0 remain, 0 are dead but not yet removable
removable cutoff: 163111, which was 0 XIDs old when operation ended
new relfrozenxid: 163111, which is 1 XIDs ahead of previous value
frozen: 0 pages from table (100.00% of total) had 0 tuples frozen
visibility map: 0 pages set all-visible, 0 pages set all-frozen (0 were all-visible)
index scan not needed: 0 pages from table (100.00% of total) had 0 dead item identifiers removed
avg read rate: 0.000 MB/s, avg write rate: 0.000 MB/s
buffer usage: 28 hits, 0 reads, 0 dirtied
WAL usage: 1 records, 0 full page images, 258 bytes, 0 buffers full
system usage: CPU: user: 0.00 s, system: 0.00 s, elapsed: 0.00 s
VACUUM
'
-- performing a query again on replica 
lab=*# SELECT count(*) FROM bloat;
FATAL:  terminating connection due to conflict with recovery
DETAIL:  User query might have needed to see row versions that must be removed.
HINT:  In a moment you should be able to reconnect to the database and repeat your command.
server closed the connection unexpectedly
        This probably means the server terminated abnormally
        before or while processing the request.
The connection to the server was lost. Attempting reset: Succeeded.


-- SETUP SYNCRONOUS REPLICATION 
-- on primary 
[vagrant@db1 ~]$ sudo -iu postgres psql <<'EOF'
ALTER SYSTEM SET synchronous_standby_names = 'db2';
SELECT pg_reload_conf();
SELECT application_name, sync_state FROM pg_stat_replication;
EOF
ALTER SYSTEM
 pg_reload_conf
----------------
 t
(1 row)

 application_name | sync_state
------------------+------------
 db2              | potential
(1 row)

-- stopping replica and performing an insert to freeze the commit 
-- on replica 
[vagrant@db2 ~]$ sudo systemctl stop postgresql-18

-- on primary 
[vagrant@db1 ~]$ sudo -iu postgres psql -d lab -c "INSERT INTO replicada VALUES (now());" (run ctrl+c to cancel the commit)
^CCancel request sent
WARNING:  canceling wait for synchronous replication due to user request
DETAIL:  The transaction has already committed locally, but might not have been replicated to the standby.
INSERT 0 1

-- rollback the primary to async mode 
[vagrant@db1 ~]$ sudo -iu postgres psql -c "ALTER SYSTEM SET synchronous_standby_names = '';" -c "SELECT pg_reload_conf();"
ALTER SYSTEM
 pg_reload_conf
----------------
 t
(1 row)

-- restarting replica 
[vagrant@db2 ~]$ sudo systemctl start postgresql-18


-- checking replication status 
[vagrant@db1 ~]$ sudo -iu postgres psql -x -c "SELECT application_name, client_addr, state, sent_lsn, replay_lsn, replay_lag, sync_state FROM pg_stat_replication;"
-[ RECORD 1 ]----+--------------
application_name | db2
client_addr      | 192.168.56.12
state            | streaming
sent_lsn         | 1/43A23F8
replay_lsn       | 1/43A23F8
replay_lag       |
sync_state       | async

[vagrant@db1 ~]$ sudo -iu postgres psql -c "SELECT slot_name, active, wal_status FROM pg_replication_slots;"
 slot_name | active | wal_status
-----------+--------+------------
 slot_db2  | t      | reserved
(1 row)


[vagrant@db2 ~]$ sudo -iu postgres psql -x -c "SELECT status, sender_host, slot_name, latest_end_lsn FROM pg_stat_wal_receiver;"
-[ RECORD 1 ]--+----------
status         | streaming
sender_host    | db1
slot_name      | slot_db2
latest_end_lsn | 1/43A23F8

[vagrant@db2 ~]$ sudo -iu postgres psql -c "SELECT pg_is_in_recovery(), pg_last_wal_replay_lsn(), pg_last_xact_replay_timestamp();"
 pg_is_in_recovery | pg_last_wal_replay_lsn | pg_last_xact_replay_timestamp
-------------------+------------------------+-------------------------------
 t                 | 1/43A23F8              | 2026-10-16 12:10:31.546246+01
(1 row)


-- FAILOVER SIMULATION 
-- stopping and fencing the primary 
[vagrant@db1 ~]$ sudo systemctl stop postgresql-18
[vagrant@db1 ~]$ sudo systemctl disable postgresql-18
Removed "/etc/systemd/system/multi-user.target.wants/postgresql-18.service".

-- promoting the replica to primary 
[vagrant@db2 ~]$ sudo -iu postgres psql -c "SELECT pg_promote();"
 pg_promote
------------
 t
(1 row)

[vagrant@db2 ~]$ sudo -iu postgres psql -c "SELECT pg_is_in_recovery();"
 pg_is_in_recovery
-------------------
 f
(1 row)

[vagrant@db2 ~]$ sudo -iu postgres psql -d lab -c "INSERT INTO replicada VALUES (now());"
INSERT 0 1
[vagrant@db2 ~]$ sudo -iu postgres /usr/pgsql-18/bin/pg_controldata /var/lib/pgsql/18/data | grep TimeLineID
Latest checkpoint's TimeLineID:       4
Latest checkpoint's PrevTimeLineID:   4

-- reintegrating the primary using pg_rewind (on db1)
sudo -iu postgres /usr/pgsql-18/bin/pg_rewind --target-pgdata=/var/lib/pgsql/18/data --source-server="host=db2 user=postgres dbname=postgres" -R -P
pg_rewind: connected to server
pg_rewind: servers diverged at WAL location 1/50000A0 on timeline 4
pg_rewind: no rewind required


-- if the password was requested, re-create the .pgpass 
printf '%s\n' 'db2:5432:*:postgres:postgres' 'db2:5432:replication:replicador:repl123' > ~/.pgpass
chmod 600 .pgpass 

-- changing the user replication (primary_conninfo)
[vagrant@db1 ~]$ sudo -iu postgres grep primary_conninfo /var/lib/pgsql/18/data/postgresql.auto.conf -- old user 
primary_conninfo = 'user=postgres passfile=''/var/lib/pgsql/.pgpass'' channel_binding=prefer host=db2 port=5432 sslmode=prefer sslnegotiation=postgres sslcompression=0 sslcertmode=allow sslsni=1 ssl_min_protocol_version=TLSv1.2 gssencmode=prefer krbsrvname=postgres gssdelegation=0 target_session_attrs=any load_balance_hosts=disable dbname=postgres'
-- chaging to replicator user
[vagrant@db1 ~]$ sudo -iu postgres sed -i "s/user=postgres/user=replicador/" /var/lib/pgsql/18/data/postgresql.auto.conf 

[vagrant@db1 ~]$ sudo -iu postgres grep primary_conninfo /var/lib/pgsql/18/data/postgresql.auto.conf 
primary_conninfo = 'user=replicador passfile=''/var/lib/pgsql/.pgpass'' channel_binding=prefer host=db2 port=5432 sslmode=prefer sslnegotiation=postgres sslcompression=0 sslcertmode=allow sslsni=1 ssl_min_protocol_version=TLSv1.2 gssencmode=prefer krbsrvname=postgres gssdelegation=0 target_session_attrs=any load_balance_hosts=disable dbname=postgres'
[vagrant@db1 ~]$

-- enabling and restarting the cluster 
[vagrant@db1 ~]$ sudo systemctl enable --now postgresql-18
Created symlink /etc/systemd/system/multi-user.target.wants/postgresql-18.service → /usr/lib/systemd/system/postgresql-18.service.

[vagrant@db1 ~]$ sudo systemctl status postgresql-18
● postgresql-18.service - PostgreSQL 18 database server
     Loaded: loaded (/usr/lib/systemd/system/postgresql-18.service; enabled; preset: disabled)
     Active: active (running) since Sat 2026-10-17 09:23:34 WEST; 45s ago
       Docs: https://www.postgresql.org/docs/18/static/
    Process: 7346 ExecStartPre=/usr/pgsql-18/bin/postgresql-18-check-db-dir ${PGDATA} (code=exited, status=0/SUCCESS)
   Main PID: 7351 (postgres)
      Tasks: 9 (limit: 12306)
     Memory: 57.5M
        CPU: 487ms
     CGroup: /system.slice/postgresql-18.service
             ├─7351 /usr/pgsql-18/bin/postgres -D /var/lib/pgsql/18/data/
             ├─7352 "postgres: db1: logger "
             ├─7353 "postgres: db1: io worker 0"
             ├─7354 "postgres: db1: io worker 1"
             ├─7355 "postgres: db1: io worker 2"
             ├─7356 "postgres: db1: checkpointer "
             ├─7357 "postgres: db1: background writer "
             ├─7358 "postgres: db1: startup recovering 000000050000000100000005"
             └─7359 "postgres: db1: walreceiver streaming 1/5002BA8"

Oct 17 09:23:34 db1 systemd[1]: Starting PostgreSQL 18 database server...
Oct 17 09:23:34 db1 postgres[7351]: 2026-10-17 09:23:34.800 WEST [7351] @ LOG:  redirecting log output to logging collector process
Oct 17 09:23:34 db1 postgres[7351]: 2026-10-17 09:23:34.800 WEST [7351] @ HINT:  Future log output will appear in directory "log".
Oct 17 09:23:34 db1 systemd[1]: Started PostgreSQL 18 database server.

-- checking in replica if the roles is inverted 
-- the db2 now is the primary and db1 is the replica
[vagrant@db2 ~]$ sudo -iu postgres psql -c "SELECT application_name, state, sync_state FROM pg_stat_replication;"
 application_name |   state   | sync_state
------------------+-----------+------------
 db1              | streaming | async        <== inverted!!!  
(1 row)

[vagrant@db2 ~]$ sudo -iu postgres psql -x -c "SELECT application_name, client_addr, state, sent_lsn, replay_lsn, replay_lag, sync_state FROM pg_stat_replication;"
-[ RECORD 1 ]----+--------------
application_name | db1                   <== replica now
client_addr      | 192.168.56.11
state            | streaming
sent_lsn         | 1/5002BA8
replay_lsn       | 1/5002BA8
replay_lag       |
sync_state       | async



-- cleaning the slot in the primary 
[vagrant@db1 ~]$ sudo -iu postgres psql -c "SELECT slot_name, active FROM pg_replication_slots;"
 slot_name | active
-----------+--------
 slot_db2  | f
(1 row)

[vagrant@db1 ~]$ sudo -iu postgres psql -c "SELECT pg_drop_replication_slot('slot_db2');"
 pg_drop_replication_slot
--------------------------

(1 row)


--- switchover manually 
-- as postgres user 

psql 
~-- checking the replica and slots (on primary)
postgres=# SELECT application_name, state, pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn) AS lag FROM pg_stat_replication;
 application_name |   state   | lag
------------------+-----------+-----
 db1              | streaming |   0
(1 row)

postgres=# SELECT slot_name, active, wal_status FROM pg_replication_slots;
 slot_name | active | wal_status
-----------+--------+------------
 slot_db1  | t      | reserved
(1 row)

-- stop the db2
[root@db2 ~]# systemctl stop postgresql-18

-- promoting the db1 as primary 
postgres=# SELECT pg_promote();
 pg_promote
------------
 t
(1 row)

postgres=# SELECT pg_is_in_recovery();
 pg_is_in_recovery
-------------------
 f
(1 row)

postgres=# SELECT pg_create_physical_replication_slot('slot_db2');
 pg_create_physical_replication_slot
-------------------------------------
 (slot_db2,)

-- setting the parameters on replica (db2) 
[postgres@db2 ~]$ touch /var/lib/pgsql/18/data/standby.signal

[postgres@db2 ~]$ tee -a /var/lib/pgsql/18/data/postgresql.auto.conf <<'EOF'
primary_conninfo = 'host=db1 port=5432 user=replicador application_name=db2'
primary_slot_name = 'slot_db2'
EOF

--leave only the last line of primary_conninfo in the config file. It must be pointed to the primary 
[postgres@db2 ~]$ cat /var/lib/pgsql/18/data/postgresql.auto.conf
# Do not edit this file manually!
# It will be overwritten by the ALTER SYSTEM command.
listen_addresses = '*'
log_line_prefix = '%m [%p] %u@%d '
shared_buffers = '512MB'
effective_cache_size = '1536MB'
work_mem = '16MB'
maintenance_work_mem = '128MB'
max_wal_size = '2GB'
checkpoint_timeout = '15min'
archive_mode = 'on'
archive_command = 'pgbackrest --stanza=lab archive-push %p'
cluster_name = 'db1'
-- remove this line primary_conninfo = 'user=replicador passfile=''/var/lib/pgsql/.pgpass'' channel_binding=prefer host=db1 port=5432 sslmode=prefer sslnegotiation=postgres sslcompression=0 sslcertmode=allow sslsni=1 ssl_min_protocol_version=TLSv1.2 gssencmode=prefer krbsrvname=postgres gssdelegation=0 target_session_attrs=any load_balance_hosts=disable'
primary_slot_name = 'slot_db2'
cluster_name = 'db2'
primary_conninfo = 'host=db1 port=5432 user=replicador application_name=db2'
primary_slot_name = 'slot_db2'

OR 
grep -nE "primary_conninfo|primary_slot_name" /var/lib/pgsql/18/data/postgresql.auto.conf

-- checking if there are missing wals to rewind(db2)
[postgres@db2 ~]$  /usr/pgsql-18/bin/pg_rewind --target-pgdata=/var/lib/pgsql/18/data --source-server="host=db1 user=postgres dbname=postgres" --dry-run
pg_rewind: servers diverged at WAL location 1/60000A0 on timeline 5
pg_rewind: no rewind required

-- starting the replica (db2) 
[root@db2 ~]# sudo systemctl start postgresql-18

-- checking the replication working (db1)
postgres=# SELECT application_name, state, sync_state FROM pg_stat_replication;
 application_name |   state   | sync_state
------------------+-----------+------------
 db2              | streaming | async
(1 row)

postgres=# SELECT slot_name, active FROM pg_replication_slots;
 slot_name | active
-----------+--------
 slot_db2  | t
(1 row)

-- drop the slop on replica 
SELECT slot_name, active FROM pg_replication_slots;
SELECT pg_drop_replication_slot('nome_do_slot');

####################################### SUMARY #################################################
Set		Where	Action									Target Status
1		db2		Confirma atraso = 0						db2 primário · db1 réplica
2		db2		Remove o slot_db1						idem
3		db2		systemctl stop	db2 					parado · db1 réplica
4		db1		pg_promote()	db2 					parado · db1 primário
5		db2		Cria standby.signal + primary_conninfo	db2 parado, configurado como réplica
7		db2		systemctl start							db1 primário · db2 réplica
################################################################################################

-- CHECKING WHICH NODE PERFORMS WHICH ROLE 
-- in the OS (walsender is on primary. walreceiver on replica)
ps -ef | grep -E "walsender|walreceiver" | grep -v grep
postgres    7825    7720  0 09:56 ?        00:00:00 postgres: db1: walsender replicador 192.168.56.12(50548) streaming 1/6001DE8

or 

[postgres@db1 ~]$ systemctl status postgresql-18.service
● postgresql-18.service - PostgreSQL 18 database server
     Loaded: loaded (/usr/lib/systemd/system/postgresql-18.service; enabled; preset: disabled)
     Active: active (running) since Sat 2026-10-17 09:44:28 WEST; 20min ago
       Docs: https://www.postgresql.org/docs/18/static/
    Process: 7715 ExecStartPre=/usr/pgsql-18/bin/postgresql-18-check-db-dir ${PGDATA} (code=exited, status=0/SUCCESS)
   Main PID: 7720 (postgres)
      Tasks: 12 (limit: 12306)
     Memory: 67.1M
        CPU: 2.812s
     CGroup: /system.slice/postgresql-18.service
             ├─7720 /usr/pgsql-18/bin/postgres -D /var/lib/pgsql/18/data/
             ├─7721 "postgres: db1: logger "
             ├─7722 "postgres: db1: io worker 0"
             ├─7723 "postgres: db1: io worker 1"
             ├─7724 "postgres: db1: io worker 2"
             ├─7725 "postgres: db1: checkpointer "
             ├─7726 "postgres: db1: background writer "
             ├─7783 "postgres: db1: walwriter "
             ├─7784 "postgres: db1: autovacuum launcher "
             ├─7785 "postgres: db1: archiver last was 000000050000000100000006.partial"
             ├─7786 "postgres: db1: logical replication launcher "
             └─7825 "postgres: db1: walsender replicador 192.168.56.12(50548) streaming 1/6001DE8"  <== THIS ONE!

ps -ef | grep -E "walsender|walreceiver" | grep -v grep
postgres   18658   18650  0 09:56 ?        00:00:00 postgres: db2: walreceiver streaming 1/6001DE8

or

[postgres@db2 ~]$  systemctl status postgresql-18.service
● postgresql-18.service - PostgreSQL 18 database server
     Loaded: loaded (/usr/lib/systemd/system/postgresql-18.service; enabled; preset: disabled)
     Active: active (running) since Sat 2026-10-17 09:56:04 WEST; 8min ago
       Docs: https://www.postgresql.org/docs/18/static/
    Process: 18645 ExecStartPre=/usr/pgsql-18/bin/postgresql-18-check-db-dir ${PGDATA} (code=exited, status=0/SUCCESS)
   Main PID: 18650 (postgres)
      Tasks: 9 (limit: 12306)
     Memory: 59.0M
        CPU: 1.001s
     CGroup: /system.slice/postgresql-18.service
             ├─18650 /usr/pgsql-18/bin/postgres -D /var/lib/pgsql/18/data/
             ├─18651 "postgres: db2: logger "
             ├─18652 "postgres: db2: io worker 0"
             ├─18653 "postgres: db2: io worker 1"
             ├─18654 "postgres: db2: io worker 2"
             ├─18655 "postgres: db2: checkpointer "
             ├─18656 "postgres: db2: background writer "
             ├─18657 "postgres: db2: startup recovering 000000060000000100000006"
             └─18658 "postgres: db2: walreceiver streaming 1/6001DE8"   <== THIS ONE!!
			 
-- in the cluster
-- f is primary
postgres=# SELECT pg_is_in_recovery();
 pg_is_in_recovery
-------------------
 f
 
-- t is replica 
postgres=# SELECT pg_is_in_recovery();
 pg_is_in_recovery
-------------------
 t

-- who is the replica (only in the primary) 
postgres=# SELECT application_name, client_addr, state, sync_state FROM pg_stat_replication;
 application_name |  client_addr  |   state   | sync_state
------------------+---------------+-----------+------------
 db2              | 192.168.56.12 | streaming | async

-- who is the primary (only in the replica) 
postgres=# SELECT status, sender_host, sender_port, slot_name FROM pg_stat_wal_receiver;
SHOW primary_conninfo;
  status   | sender_host | sender_port | slot_name
-----------+-------------+-------------+-----------
 streaming | db1         |        5432 | slot_db2
(1 row)

                    primary_conninfo
---------------------------------------------------------
 host=db1 port=5432 user=replicador application_name=db2
(1 row)


-- script to perform in any nodes 
SELECT inet_server_addr()                       AS ip,
       current_setting('cluster_name')          AS name,
       CASE WHEN pg_is_in_recovery() THEN 'REPLICA' ELSE 'PRIMARY' END AS role,
       (SELECT timeline_id FROM pg_control_checkpoint()) AS timeline,
       (SELECT count(*) FROM pg_stat_replication)        AS replicas_connected,
       (SELECT sender_host FROM pg_stat_wal_receiver)    AS sender;

-- result from primary 
 ip | name |  role   | timeline | replicas_connected | sender
----+------+---------+----------+--------------------+--------
    | db1  | PRIMARY |        6 |                  1 |
	
-- result from replica 
 ip | name |  role   | timeline | replicas_connected | sender
----+------+---------+----------+--------------------+--------
    | db2  | REPLICA |        6 |                  0 | db1
	
-- if the node is DOWN 
/usr/pgsql-18/bin/pg_controldata /var/lib/pgsql/18/data | grep -E "cluster state|TimeLineID|checkpoint location"
Database cluster state:               in production
Latest checkpoint location:           1/6001D38
Latest checkpoint's TimeLineID:       6
Latest checkpoint's PrevTimeLineID:   6

/usr/pgsql-18/bin/pg_controldata /var/lib/pgsql/18/data | grep -E "cluster state|TimeLineID|checkpoint location"
Database cluster state:               in archive recovery
Latest checkpoint location:           1/6001D38
Latest checkpoint's TimeLineID:       6
Latest checkpoint's PrevTimeLineID:   6

Database cluster state		Means
in production				PRIMARY
in archive recovery			REPLICA
shut down					PRIMARY SHUT DOWN
shut down in recovery		REPLICA SHUT DOWN

-- SPLIT BRAIN SITUATION 
If SELECT pg_is_in_recovery() = f in both nodes 
1- compare the timeline between the nodes. The most recently is the primary

-- checking lag 
-- on primary 
postgres=# SELECT application_name,
       state,
       pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), sent_lsn))   AS falta_enviar,
       pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), flush_lsn))  AS falta_gravar,
       pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn)) AS falta_aplicar,
       write_lag, flush_lag, replay_lag
FROM pg_stat_replication;
 application_name |   state   | falta_enviar | falta_gravar | falta_aplicar | write_lag | flush_lag | replay_lag
------------------+-----------+--------------+--------------+---------------+-----------+-----------+------------
 db1              | streaming | 0 bytes      | 0 bytes      | 0 bytes       |           |           |


-- on standby 
postgres=# SELECT pg_is_in_recovery()                                                AS replica,
       pg_size_pretty(pg_wal_lsn_diff(pg_last_wal_receive_lsn(),
                                      pg_last_wal_replay_lsn()))           AS recebido_nao_aplicado,
       now() - pg_last_xact_replay_timestamp()                             AS atraso_tempo;
 replica | recebido_nao_aplicado | atraso_tempo
---------+-----------------------+--------------
 t       | 0 bytes               |

