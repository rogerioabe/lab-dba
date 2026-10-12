###########################################################
## LAB 01 - TESTING MEMORY TUNING 
###########################################################

-- Create the bench enviroment 
[vagrant@db1 lib]$ psql -h localhost -U dba -d lab -c "CREATE DATABASE bench;"
Password for user dba:
CREATE DATABASE
[vagrant@db1 lib]$ /usr/pgsql-18/bin/pgbench -h localhost -U dba -i -s 50 bench
Password:
dropping old tables...
NOTICE:  table "pgbench_accounts" does not exist, skipping
NOTICE:  table "pgbench_branches" does not exist, skipping
NOTICE:  table "pgbench_history" does not exist, skipping
NOTICE:  table "pgbench_tellers" does not exist, skipping
creating tables...
generating data (client-side)...
vacuuming...
creating primary keys...
done in 35.86 s (drop tables 0.01 s, create tables 0.03 s, client-side generate 24.81 s, vacuum 2.43 s, primary keys 8.57 s).
[vagrant@db1 lib]$ psql -h localhost -U dba -d bench -c "SELECT pg_size_pretty(pg_database_size('bench'));"
Password for user dba:
 pg_size_pretty
----------------
 755 MB
(1 row)

-- dry-run test 
[vagrant@db1 lib]$ /usr/pgsql-18/bin/pgbench -h localhost -U dba -c 8 -j 2 -T 60 bench
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
number of transactions actually processed: 12989
number of failed transactions: 0 (0.000%)
latency average = 36.922 ms
initial connection time = 129.295 ms
tps = 216.674046 (without initial connection time)
[vagrant@db1 lib]$ /usr/pgsql-18/bin/pgbench -h localhost -U dba -c 8 -j 2 -T 60 bench
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
number of transactions actually processed: 12929
number of failed transactions: 0 (0.000%)
latency average = 37.098 ms
initial connection time = 131.999 ms
tps = 215.647509 (without initial connection time)
[vagrant@db1 lib]$ /usr/pgsql-18/bin/pgbench -h localhost -U dba -c 8 -j 2 -T 60 bench
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
number of transactions actually processed: 12283
number of failed transactions: 0 (0.000%)
latency average = 39.028 ms
initial connection time = 139.353 ms
tps = 204.981116 (without initial connection time)
[vagrant@db1 lib]$

-- checking memory parameter 
[vagrant@db1 lib]$ sudo -iu postgres psql -c "SELECT name, setting, unit, source FROM pg_settings WHERE name IN ('shared_buffers','effective_cache_size','work_mem','max_wal_size','checkpoint_timeout');"
         name         | setting | unit |       source
----------------------+---------+------+--------------------
 checkpoint_timeout   | 300     | s    | default
 effective_cache_size | 524288  | 8kB  | default
 max_wal_size         | 1024    | MB   | configuration file
 shared_buffers       | 32768   | 8kB  | configuration file
 work_mem             | 4096    | kB   | default
(5 rows)

sudo -iu postgres psql -h db1
sudo -iu postgres psql -c "ALTER SYSTEM SET log_line_prefix = '%m [%p] %u@%d ';"
sudo -iu postgres psql -c "SELECT pg_reload_conf();"

-- checking typos in config file
SELECT sourceline, name, setting, applied, error FROM pg_file_settings WHERE error IS NOT NULL OR NOT applied;


/usr/pgsql-18/bin/pgbench -h localhost -U dba -c 8 -j 2 -T 60 bench
sudo su -
sudo tail -30 /var/lib/pgsql/18/data/log/postgresql-*.log | grep -i checkpoint[root@db1 ~]# tail -30 /var/lib/pgsql/18/data/log/postgresql-Mon.log | grep -i checkpoint
2026-10-12 10:18:30.057 WEST [4814] LOG:  checkpoint starting: wal
2026-10-12 10:22:46.960 WEST [4814] LOG:  checkpoint complete: wrote 2329 buffers (7.1%), wrote 1 SLRU buffers; 0 WAL file(s) added, 0 removed, 33 recycled; write=254.804 s, sync=1.402 s, total=256.904 s; sync files=326, longest=0.026 s, average=0.005 s; distance=542233 kB, estimate=542233 kB; lsn=0/9307A1D0, redo lsn=0/7F633D40
2026-10-12 10:23:30.988 WEST [4814] LOG:  checkpoint starting: time
2026-10-12 10:28:00.301 WEST [4814] LOG:  checkpoint complete: wrote 28060 buffers (85.6%), wrote 7 SLRU buffers; 0 WAL file(s) added, 0 removed, 22 recycled; write=269.064 s, sync=0.066 s, total=269.313 s; sync files=25, longest=0.011 s, average=0.003 s; distance=360776 kB, estimate=524087 kB; lsn=0/956D8CA8, redo lsn=0/95685E00
[root@db1 ~]# exit
logout
[vagrant@db1 lib]$ sudo -iu postgres psql -c "SELECT num_timed, num_requested, write_time, sync_time FROM pg_stat_checkpointer;"
 num_timed | num_requested | write_time | sync_time
-----------+---------------+------------+-----------
       550 |             6 |    1208076 |      4049
(1 row)

-- tuning memory parameters 
[vagrant@db1 lib]$ sudo -iu postgres psql -h db1
Password for user postgres:
psql (18.6)
Type "help" for help.

postgres=#
postgres=# ALTER SYSTEM SET shared_buffers = '512MB';
ALTER SYSTEM SET effective_cache_size = '1536MB';
ALTER SYSTEM SET work_mem = '16MB';
ALTER SYSTEM SET maintenance_work_mem = '128MB';
ALTER SYSTEM SET max_wal_size = '2GB';
ALTER SYSTEM SET checkpoint_timeout = '15min';
ALTER SYSTEM
ALTER SYSTEM
ALTER SYSTEM
ALTER SYSTEM
ALTER SYSTEM
ALTER SYSTEM
postgres=#
postgres=# SELECT pg_reload_conf();
 pg_reload_conf
----------------
 t
(1 row)

postgres=# SELECT name, setting, pending_restart FROM pg_settings WHERE pending_restart;
      name      | setting | pending_restart
----------------+---------+-----------------
 shared_buffers | 32768   | t
(1 row)

postgres=# \q
[vagrant@db1 lib]$ sudo systemctl restart postgresql-18
[vagrant@db1 lib]$ sudo systemctl status postgresql-18
● postgresql-18.service - PostgreSQL 18 database server
     Loaded: loaded (/usr/lib/systemd/system/postgresql-18.service; enabled; preset: disabled)
     Active: active (running) since Mon 2026-10-12 10:36:32 WEST; 6s ago
       Docs: https://www.postgresql.org/docs/18/static/
    Process: 18037 ExecStartPre=/usr/pgsql-18/bin/postgresql-18-check-db-dir ${PGDATA} (code=exited, status=0/SUCCESS)
   Main PID: 18042 (postgres)
      Tasks: 10 (limit: 12306)
     Memory: 42.2M
        CPU: 310ms
     CGroup: /system.slice/postgresql-18.service
             ├─18042 /usr/pgsql-18/bin/postgres -D /var/lib/pgsql/18/data/
             ├─18043 "postgres: logger "
             ├─18044 "postgres: io worker 0"
             ├─18045 "postgres: io worker 2"
             ├─18046 "postgres: io worker 1"
             ├─18047 "postgres: checkpointer "
             ├─18048 "postgres: background writer "
             ├─18050 "postgres: walwriter "
             ├─18051 "postgres: autovacuum launcher "
             └─18052 "postgres: logical replication launcher "

Oct 12 10:36:31 db1 systemd[1]: Starting PostgreSQL 18 database server...
Oct 12 10:36:31 db1 postgres[18042]: 2026-10-12 10:36:31.986 WEST [18042] @ LOG:  redirecting log output to logging collector process
Oct 12 10:36:31 db1 postgres[18042]: 2026-10-12 10:36:31.986 WEST [18042] @ HINT:  Future log output will appear in directory "log".
Oct 12 10:36:32 db1 systemd[1]: Started PostgreSQL 18 database server.

-- recreating the bench environment
[vagrant@db1 lib]$ /usr/pgsql-18/bin/pgbench -h localhost -U dba -i -s 50 bench
Password:
dropping old tables...
creating tables...
generating data (client-side)...
vacuuming...
creating primary keys...
done in 24.62 s (drop tables 0.20 s, create tables 0.07 s, client-side generate 16.14 s, vacuum 1.86 s, primary keys 6.35 s).

-- dry-run testing
[vagrant@db1 lib]$ /usr/pgsql-18/bin/pgbench -h localhost -U dba -c 8 -j 2 -T 30 bench
Password:
pgbench (18.6)
starting vacuum...end.
transaction type: <builtin: TPC-B (sort of)>
scaling factor: 50
query mode: simple
number of clients: 8
number of threads: 2
maximum number of tries: 1
duration: 30 s
number of transactions actually processed: 6235
number of failed transactions: 0 (0.000%)
latency average = 38.372 ms
initial connection time = 156.494 ms
tps = 208.486410 (without initial connection time)
[vagrant@db1 lib]$ /usr/pgsql-18/bin/pgbench -h localhost -U dba -c 8 -j 2 -T 60 bench
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
number of transactions actually processed: 13463
number of failed transactions: 0 (0.000%)
latency average = 35.601 ms
initial connection time = 144.767 ms
tps = 224.710189 (without initial connection time)
[vagrant@db1 lib]$ /usr/pgsql-18/bin/pgbench -h localhost -U dba -c 8 -j 2 -T 60 bench
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
number of transactions actually processed: 13561
number of failed transactions: 0 (0.000%)
latency average = 35.356 ms
initial connection time = 128.208 ms
tps = 226.271630 (without initial connection time)
[vagrant@db1 lib]$ /usr/pgsql-18/bin/pgbench -h localhost -U dba -c 8 -j 2 -T 60 bench
Password:
pgbench: error: connection to server at "localhost" (::1), port 5432 failed: FATAL:  password authentication failed for user "dba"
pgbench: error: could not create connection for setup
[vagrant@db1 lib]$ /usr/pgsql-18/bin/pgbench -h localhost -U dba -c 8 -j 2 -T 60 bench
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
number of transactions actually processed: 13585
number of failed transactions: 0 (0.000%)
latency average = 35.297 ms
initial connection time = 142.425 ms
tps = 226.646528 (without initial connection time)
[vagrant@db1 lib]$


-- after paramenter tuning, the TPS increased about 20%. (204 x 226). 20% of performance improvement!!!

-- checking TPS in a real prod environment:
-- dry-run test
[vagrant@db1 lib]$ /usr/pgsql-18/bin/pgbench -h localhost -U dba -c 8 -j 2 -T 60 bench
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
number of transactions actually processed: 11718
number of failed transactions: 0 (0.000%)
latency average = 40.910 ms
initial connection time = 158.036 ms
tps = 195.550592 (without initial connection time)

-- checking in another session real time 
postgres=# SELECT now()::time(0) AS hora, xact_commit + xact_rollback AS total_transacoes
FROM pg_stat_database WHERE datname = 'bench' \watch 10
Mon 12 Oct 2026 11:08:38 AM WEST (every 10s)

   hora   | total_transacoes
----------+------------------
 11:08:38 |           136651
(1 row)

Mon 12 Oct 2026 11:08:48 AM WEST (every 10s)

   hora   | total_transacoes
----------+------------------
 11:08:48 |           138499
(1 row)

Mon 12 Oct 2026 11:08:58 AM WEST (every 10s)

   hora   | total_transacoes
----------+------------------
 11:08:58 |           140429
(1 row)

Mon 12 Oct 2026 11:09:08 AM WEST (every 10s)

   hora   | total_transacoes
----------+------------------
 11:09:08 |           142266
(1 row)

Mon 12 Oct 2026 11:09:18 AM WEST (every 10s)

   hora   | total_transacoes
----------+------------------
 11:09:18 |           144244   <=== sample for comparison
(1 row)

Mon 12 Oct 2026 11:09:28 AM WEST (every 10s)

   hora   | total_transacoes
----------+------------------
 11:09:28 |           146373    <=== sample for comparison
(1 row)

Mon 12 Oct 2026 11:09:38 AM WEST (every 10s)

   hora   | total_transacoes
----------+------------------
 11:09:38 |           148032
(1 row)

Mon 12 Oct 2026 11:09:48 AM WEST (every 10s)

   hora   | total_transacoes
----------+------------------
 11:09:48 |           148043
(1 row)

Mon 12 Oct 2026 11:09:58 AM WEST (every 10s)

   hora   | total_transacoes
----------+------------------
 11:09:58 |           148043
(1 row)

Mon 12 Oct 2026 11:10:08 AM WEST (every 10s)

   hora   | total_transacoes
----------+------------------
 11:10:08 |           148043
(1 row)

Mon 12 Oct 2026 11:10:18 AM WEST (every 10s)

   hora   | total_transacoes
----------+------------------
 11:10:18 |           148043
(1 row)

Mon 12 Oct 2026 11:10:28 AM WEST (every 10s)

   hora   | total_transacoes
----------+------------------
 11:10:28 |           148043
(1 row)

Mon 12 Oct 2026 11:10:38 AM WEST (every 10s)

   hora   | total_transacoes
----------+------------------
 11:10:38 |           148043
(1 row)


-- calculation: (146373-144244)/10 = 213  - (bench 195 x View 213) 
-- CONCLUSIONS: bench test consider all samples, so I can rely on pga_stat_database view due to similar result

-- views to measure TPS
SELECT now()::time(0) AS hora, xact_commit + xact_rollback AS total_transacoes
FROM pg_stat_database WHERE datname = 'bench' \watch 10

WITH t1 AS (
  SELECT xact_commit + xact_rollback AS total, clock_timestamp() AS ts
  FROM pg_stat_database WHERE datname = 'bench'
), espera AS (SELECT pg_sleep(10)),
t2 AS (
  SELECT xact_commit + xact_rollback AS total, clock_timestamp() AS ts
  FROM pg_stat_database, espera WHERE datname = 'bench'
)
SELECT round((t2.total - t1.total) / extract(epoch FROM t2.ts - t1.ts)) AS tps
FROM t1, t2;


