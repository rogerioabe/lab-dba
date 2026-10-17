##################################################
## LAB LOGICAL REPLICA AND PATRONI
##################################################

-- backup before patroni 
[postgres@db1 ~]$ pg_dumpall -f /backup/antes_patroni.sql

-- changing wal level to logical (on db1)
[postgres@db1 ~]$ psql -c "ALTER SYSTEM SET wal_level = 'logical';"

ALTER SYSTEM
[postgres@db1 ~]$
[postgres@db1 ~]$ exit
logout
[root@db1 ~]# sudo systemctl restart postgresql-18
[root@db1 ~]# sudo systemctl status postgresql-18
● postgresql-18.service - PostgreSQL 18 database server
     Loaded: loaded (/usr/lib/systemd/system/postgresql-18.service; enabled; preset: disabled)
     Active: active (running) since Sat 2026-10-17 14:42:40 WEST; 2s ago
       Docs: https://www.postgresql.org/docs/18/static/
    Process: 9656 ExecStartPre=/usr/pgsql-18/bin/postgresql-18-check-db-dir ${PGDATA} (code=exited, status=0/SUCCESS)
   Main PID: 9662 (postgres)
      Tasks: 11 (limit: 12306)
     Memory: 46.2M
        CPU: 221ms
     CGroup: /system.slice/postgresql-18.service
             ├─9662 /usr/pgsql-18/bin/postgres -D /var/lib/pgsql/18/data/
             ├─9663 "postgres: db1: logger "
             ├─9664 "postgres: db1: io worker 0"
             ├─9665 "postgres: db1: io worker 1"
             ├─9666 "postgres: db1: io worker 2"
             ├─9667 "postgres: db1: checkpointer "
             ├─9668 "postgres: db1: background writer "
             ├─9670 "postgres: db1: walwriter "
             ├─9671 "postgres: db1: autovacuum launcher "
             ├─9672 "postgres: db1: archiver "
             └─9673 "postgres: db1: logical replication launcher "

Oct 17 14:42:40 db1 systemd[1]: Starting PostgreSQL 18 database server...
Oct 17 14:42:40 db1 postgres[9662]: 2026-10-17 14:42:40.562 WEST [9662] @ LOG:  redirecting log output to logging collector process
Oct 17 14:42:40 db1 postgres[9662]: 2026-10-17 14:42:40.562 WEST [9662] @ HINT:  Future log output will appear in directory "log".
Oct 17 14:42:40 db1 systemd[1]: Started PostgreSQL 18 database server.
[root@db1 ~]# su - postgres
Last login: Sat Oct 17 11:32:50 WEST 2026 on pts/0

[postgres@db1 ~]$ psql -c "SHOW wal_level;"
 wal_level
-----------
 logical
(1 row)

-- setting cluster on db3 
-- creating the cluster
[vagrant@db3 ~]$ sudo /usr/pgsql-18/bin/postgresql-18-setup initdb
Initializing database ... OK

-- changing the listen_addresses parameter
[vagrant@db3 ~]$ echo "listen_addresses = '*'" | sudo -iu postgres tee -a /var/lib/pgsql/18/data/postgresql.auto.conf
listen_addresses = '*'

-- starting the cluster
[vagrant@db3 ~]$ sudo systemctl start postgresql-18
[vagrant@db3 ~]$ sudo systemctl status postgresql-18
● postgresql-18.service - PostgreSQL 18 database server
     Loaded: loaded (/usr/lib/systemd/system/postgresql-18.service; disabled; preset: disabled)
     Active: active (running) since Sat 2026-10-17 14:45:02 WEST; 13s ago
       Docs: https://www.postgresql.org/docs/18/static/
    Process: 5630 ExecStartPre=/usr/pgsql-18/bin/postgresql-18-check-db-dir ${PGDATA} (code=exited, status=0/SUCCESS)
   Main PID: 5635 (postgres)
      Tasks: 10 (limit: 12306)
     Memory: 21.9M
        CPU: 211ms
     CGroup: /system.slice/postgresql-18.service
             ├─5635 /usr/pgsql-18/bin/postgres -D /var/lib/pgsql/18/data/
             ├─5636 "postgres: logger "
             ├─5637 "postgres: io worker 0"
             ├─5638 "postgres: io worker 1"
             ├─5639 "postgres: io worker 2"
             ├─5640 "postgres: checkpointer "
             ├─5641 "postgres: background writer "
             ├─5643 "postgres: walwriter "
             ├─5644 "postgres: autovacuum launcher "
             └─5645 "postgres: logical replication launcher "

Oct 17 14:45:01 db3 systemd[1]: Starting PostgreSQL 18 database server...
Oct 17 14:45:02 db3 postgres[5635]: 2026-10-17 14:45:02.116 WEST [5635] LOG:  redirecting log output to logging collector process
Oct 17 14:45:02 db3 postgres[5635]: 2026-10-17 14:45:02.116 WEST [5635] HINT:  Future log output will appear in directory "log".
Oct 17 14:45:02 db3 systemd[1]: Started PostgreSQL 18 database server.
~

-- exporting ddl vendas from db1
[vagrant@db3 ~]$ pg_dump -h db1 -U postgres -d vendas -s -n loja > /tmp/loja_ddl.sql
Password:

-- creating database vendas 
[postgres@db3 ~]$ psql -c "CREATE DATABASE vendas;"
CREATE DATABASE

-- creating roles 
[postgres@db3 ~]$ psql -c "CREATE ROLE bruno; CREATE ROLE ana; CREATE ROLE app_leitura; CREATE ROLE app_escrita;"
CREATE ROLE
CREATE ROLE
CREATE ROLE
CREATE ROLE

-- loading the DDL 
[postgres@db3 vagrant]$ psql -d vendas -f /vagrant/loja_ddl.sql
SET
SET
SET
SET
SET
SET
 set_config
------------

(1 row)

SET
SET
SET
SET
CREATE SCHEMA
ALTER SCHEMA
SET
SET
CREATE TABLE
ALTER TABLE
CREATE SEQUENCE
ALTER SEQUENCE
ALTER SEQUENCE
psql:/vagrant/loja_ddl.sql:69: ERROR:  invalid value for parameter "default_tablespace": "ts_rapida"
DETAIL:  Tablespace "ts_rapida" does not exist.
CREATE TABLE
ALTER TABLE
CREATE SEQUENCE
ALTER SEQUENCE
ALTER SEQUENCE
SET
CREATE TABLE
ALTER TABLE
CREATE SEQUENCE
ALTER SEQUENCE
ALTER SEQUENCE
ALTER TABLE
ALTER TABLE
ALTER TABLE
ALTER TABLE
ALTER TABLE
GRANT
GRANT
GRANT
ALTER DEFAULT PRIVILEGES

-- creating publication on primary (db1) 
[postgres@db1 vagrant]$ psql -d vendas
psql (18.6)
Type "help" for help.

vendas=# CREATE PUBLICATION pub_loja FOR TABLES IN SCHEMA loja;
CREATE PUBLICATION
vendas=# GRANT USAGE ON SCHEMA loja TO replicador;
GRANT
vendas=# GRANT SELECT ON ALL TABLES IN SCHEMA loja TO replicador;
GRANT
vendas=# SELECT * FROM pg_publication_tables;
 pubname  | schemaname | tablename |  attnames  | rowfilter
----------+------------+-----------+------------+-----------
 pub_loja | loja       | pedidos   | {id,valor} |
 pub_loja | loja       | clientes  | {id,nome}  |
 pub_loja | loja       | teste     | {id}       |
(3 rows)

-- setting the password file 
echo "db1:5432:vendas:replicador:repl123" | sudo -iu postgres tee /var/lib/pgsql/.pgpass
sudo -iu postgres chmod 600 /var/lib/pgsql/.pgpass

-- creating subscription on db3 
[postgres@db3 ~]$ psql -d vendas
psql (18.6)
Type "help" for help.

vendas=# CREATE SUBSCRIPTION sub_loja CONNECTION 'host=db1 dbname=vendas user=replicador' PUBLICATION pub_loja;
NOTICE:  created replication slot "sub_loja" on publisher
CREATE SUBSCRIPTION
vendas=# SELECT * FROM loja.pedidos;
 id | valor
----+-------
  1 |   100
  2 |   250
(2 rows)

-- O pg_hba.conf do db1 precisa aceitar o replicador no banco vendas: 
-- a linha host all all 192.168.56.0/24 cobre isso. A linha replication vale só para a replicação física.

-- monitoring
-- db1 
postgres=# \c vendas
You are now connected to database "vendas" as user "postgres".
vendas=# INSERT INTO loja.pedidos (valor) VALUES (999);
INSERT 0 1
vendas=# SELECT slot_name, slot_type, active FROM pg_replication_slots;
 slot_name | slot_type | active
-----------+-----------+--------
 slot_db2  | physical  | t
 sub_loja  | logical   | t
(2 rows)

-- db3 
postgres=# \c vendas
You are now connected to database "vendas" as user "postgres".
vendas=# SELECT * FROM loja.pedidos WHERE valor = 999;
 id | valor
----+-------
  3 |   999
(1 row)

vendas=# SELECT subname, received_lsn, latest_end_lsn FROM pg_stat_subscription;
 subname  | received_lsn | latest_end_lsn
----------+--------------+----------------
 sub_loja | 1/2300C1F0   | 1/2300C1F0
(1 row)

-- creating a conflict 
-- db3: insira uma linha com um id que o db1 ainda vai usar
INSERT INTO loja.pedidos (id, valor) VALUES (1000, 1);
-- db1: gere o mesmo id
INSERT INTO loja.pedidos (id, valor) VALUES (1000, 2);

-- checking the log db3
vi /var/lib/pgsql/18/data/log/postgresql-Sat.log

2026-10-17 15:08:44.292 WEST [5901] ERROR:  conflict detected on relation "loja.pedidos": conflict=insert_exists
2026-10-17 15:08:44.292 WEST [5901] DETAIL:  Key already exists in unique index "pedidos_pkey", modified in transaction 808.
        Key (id)=(1000); existing local row (1000, 1); remote row (1000, 2).
		
-- cleaning the subscriptions 
-- db3 
vendas=# DROP SUBSCRIPTION sub_loja;
NOTICE:  dropped replication slot "sub_loja" on publisher
DROP SUBSCRIPTION

-- db1 
vendas=# DROP PUBLICATION pub_loja;
DROP PUBLICATION
vendas=# SELECT slot_name FROM pg_replication_slots WHERE slot_type = 'logical';
 slot_name
-----------
(0 rows)


-- removing cluster from all nodes (db1, db2 e db3) 
-- db3 
[root@db3 ~]# systemctl stop postgresql-18
[root@db3 ~]# systemctl disable postgresql-18
[root@db3 ~]# mv /var/lib/pgsql/18/data /var/lib/pgsql/18/data_pre_patroni 2>/dev/null
[root@db3 ~]# rm -rf /pgdata/ts_rapida/*
*/
--db2 
[root@db2 ~]# systemctl disable postgresql-18
Removed "/etc/systemd/system/multi-user.target.wants/postgresql-18.service".
[root@db2 ~]# systemctl stop postgresql-18
[root@db2 ~]# mv /var/lib/pgsql/18/data /var/lib/pgsql/18/data_pre_patroni 2>/dev/null
[root@db2 ~]# rm -rf /pgdata/ts_rapida/*
*/
-- db1
[root@db1 ~]# systemctl stop postgresql-18
[root@db1 ~]# systemctl disable postgresql-18
Removed "/etc/systemd/system/multi-user.target.wants/postgresql-18.service".
[root@db1 ~]# mv /var/lib/pgsql/18/data /var/lib/pgsql/18/data_pre_patroni 2>/dev/null
[root@db1 ~]# rm -rf /pgdata/ts_rapida/*
*/
-- installing Patroni in all nodes 
-- db1 
[root@db1 ~]# dnf install -y epel-release
Last metadata expiration check: 0:21:21 ago on Sat 17 Oct 2026 02:58:43 PM WEST.
Package epel-release-9-10.el9.noarch is already installed.
Dependencies resolved.
=================================================================================================================================================================================================================
 Package                                                Architecture                                     Version                                            Repository                                      Size
=================================================================================================================================================================================================================
Upgrading:
 epel-release                                           noarch                                           9-11.el9                                           epel                                            19 k

Transaction Summary
=================================================================================================================================================================================================================
Upgrade  1 Package

Total download size: 19 k
Downloading Packages:
epel-release-9-11.el9.noarch.rpm                                                                                                                                                  13 kB/s |  19 kB     00:01
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Total                                                                                                                                                                             10 kB/s |  19 kB     00:01
Running transaction check
Transaction check succeeded.
Running transaction test
Transaction test succeeded.
Running transaction
  Preparing        :                                                                                                                                                                                         1/1
  Upgrading        : epel-release-9-11.el9.noarch                                                                                                                                                            1/2
  Running scriptlet: epel-release-9-11.el9.noarch                                                                                                                                                            1/2
  Cleanup          : epel-release-9-10.el9.noarch                                                                                                                                                            2/2
  Running scriptlet: epel-release-9-10.el9.noarch                                                                                                                                                            2/2
  Verifying        : epel-release-9-11.el9.noarch                                                                                                                                                            1/2
  Verifying        : epel-release-9-10.el9.noarch                                                                                                                                                            2/2

Upgraded:
  epel-release-9-11.el9.noarch

Complete!


[root@db1 ~]# dnf --enablerepo=pgdg-rhel9-extras install -y etcd patroni patroni-etcd
Extra packages to support some RPMs in the PostgreSQL RPM repo for RHEL / Rocky Linux / AlmaLinux 9.6 - x86_64                                                                   1.6 kB/s | 659  B     00:00
Extra packages to support some RPMs in the PostgreSQL RPM repo for RHEL / Rocky Linux / AlmaLinux 9.6 - x86_64                                                                   527 kB/s | 2.4 kB     00:00
Importing GPG key 0x08B40D20:
 Userid     : "PostgreSQL RPM Repository <pgsql-pkg-yum@lists.postgresql.org>"
 Fingerprint: D4BF 08AE 67A0 B4C7 A1DB CCD2 40BC A2B4 08B4 0D20
 From       : /etc/pki/rpm-gpg/PGDG-RPM-GPG-KEY-RHEL
Extra packages to support some RPMs in the PostgreSQL RPM repo for RHEL / Rocky Linux / AlmaLinux 9.6 - x86_64                                                                   108 kB/s |  47 kB     00:00
Dependencies resolved.
=================================================================================================================================================================================================================
 Package                                                Architecture                          Version                                                     Repository                                        Size
=================================================================================================================================================================================================================
Installing:
 etcd                                                   x86_64                                3.7.2-1PGDG.rhel9.6                                         pgdg-rhel9-extras                                 17 M
 patroni                                                noarch                                4.1.5-1PGDG.rhel9.6                                         pgdg-common                                      1.4 M
 patroni-etcd                                           noarch                                4.1.5-1PGDG.rhel9.6                                         pgdg-common                                       10 k
Installing dependencies:
 libnsl2                                                x86_64                                2.0.0-1.el9.0.1                                             appstream                                         30 k
 mpdecimal                                              x86_64                                2.5.1-3.el9                                                 appstream                                         85 k
 py-consul                                              noarch                                1.6.0-44PGDG.rhel9                                          pgdg-common                                       64 k
 python3-ydiff                                          noarch                                1.4.2-46PGDG.rhel9                                          pgdg-common                                       36 k
 python3.12                                             x86_64                                3.12.13-2.el9_8                                             appstream                                         26 k
 python3.12-cffi                                        x86_64                                1.16.0-2.el9                                                appstream                                        297 k
 python3.12-click                                       noarch                                8.1.7-43PGDG.rhel9                                          pgdg-common                                      226 k
 python3.12-cryptography                                x86_64                                41.0.7-3.el9                                                appstream                                        1.2 M
 python3.12-dateutil                                    noarch                                2.9.0.post0-7PGDG.rhel9.6                                   pgdg-common                                      328 k
 python3.12-dns                                         noarch                                2.8.0-45PGDG.rhel9.6                                        pgdg-common                                      586 k
 python3.12-etcd                                        noarch                                0.4.5-48PGDG.rhel9                                          pgdg-common                                       98 k
 python3.12-idna                                        noarch                                3.4-2.el9                                                   appstream                                        104 k
 python3.12-libs                                        x86_64                                3.12.13-2.el9_8                                             appstream                                        9.2 M
 python3.12-pip-wheel                                   noarch                                23.2.1-5.el9                                                appstream                                        1.5 M
 python3.12-ply                                         noarch                                3.11-2.el9                                                  appstream                                        131 k
 python3.12-prettytable                                 noarch                                3.4.0-43PGDG.rhel9                                          pgdg-common                                       66 k
 python3.12-psutil                                      x86_64                                6.1.1-42PGDG.rhel9                                          pgdg-common                                      262 k
 python3.12-psycopg2                                    x86_64                                2.9.10-1PGDG.rhel9                                          pgdg-common                                      202 k
 python3.12-pycparser                                   noarch                                2.20-2.el9                                                  appstream                                        143 k
 python3.12-pyyaml                                      x86_64                                6.0.1-2.el9                                                 appstream                                        208 k
 python3.12-six                                         noarch                                1.17.0-1PGDG.rhel9                                          pgdg-common                                       40 k
 python3.12-systemd                                     x86_64                                235-42PGDG.rhel9.6                                          pgdg-common                                      100 k
 python3.12-urllib3                                     noarch                                1.26.19-3.el9_8                                             appstream                                        258 k
 python3.12-wcwidth                                     noarch                                0.2.13-2PGDG.rhel9                                          pgdg-common                                       46 k

Transaction Summary
=================================================================================================================================================================================================================
Install  27 Packages

Total download size: 33 M
Installed size: 124 M
Downloading Packages:
(1/27): patroni-etcd-4.1.5-1PGDG.rhel9.6.noarch.rpm                                                                                                                               53 kB/s |  10 kB     00:00
(2/27): py-consul-1.6.0-44PGDG.rhel9.noarch.rpm                                                                                                                                  314 kB/s |  64 kB     00:00
(3/27): patroni-4.1.5-1PGDG.rhel9.6.noarch.rpm                                                                                                                                   5.7 MB/s | 1.4 MB     00:00
(4/27): python3-ydiff-1.4.2-46PGDG.rhel9.noarch.rpm                                                                                                                              652 kB/s |  36 kB     00:00
(5/27): python3.12-click-8.1.7-43PGDG.rhel9.noarch.rpm                                                                                                                           3.4 MB/s | 226 kB     00:00
(6/27): python3.12-dateutil-2.9.0.post0-7PGDG.rhel9.6.noarch.rpm                                                                                                                 4.7 MB/s | 328 kB     00:00
(7/27): python3.12-dns-2.8.0-45PGDG.rhel9.6.noarch.rpm                                                                                                                           7.4 MB/s | 586 kB     00:00
(8/27): python3.12-etcd-0.4.5-48PGDG.rhel9.noarch.rpm                                                                                                                            1.5 MB/s |  98 kB     00:00
(9/27): python3.12-prettytable-3.4.0-43PGDG.rhel9.noarch.rpm                                                                                                                     948 kB/s |  66 kB     00:00
(10/27): python3.12-psycopg2-2.9.10-1PGDG.rhel9.x86_64.rpm                                                                                                                       2.8 MB/s | 202 kB     00:00
(11/27): python3.12-psutil-6.1.1-42PGDG.rhel9.x86_64.rpm                                                                                                                         2.8 MB/s | 262 kB     00:00
(12/27): python3.12-six-1.17.0-1PGDG.rhel9.noarch.rpm                                                                                                                            605 kB/s |  40 kB     00:00
(13/27): python3.12-systemd-235-42PGDG.rhel9.6.x86_64.rpm                                                                                                                        1.3 MB/s | 100 kB     00:00
(14/27): python3.12-wcwidth-0.2.13-2PGDG.rhel9.noarch.rpm                                                                                                                        561 kB/s |  46 kB     00:00
(15/27): libnsl2-2.0.0-1.el9.0.1.x86_64.rpm                                                                                                                                      370 kB/s |  30 kB     00:00
(16/27): mpdecimal-2.5.1-3.el9.x86_64.rpm                                                                                                                                        1.1 MB/s |  85 kB     00:00
(17/27): python3.12-3.12.13-2.el9_8.x86_64.rpm                                                                                                                                   704 kB/s |  26 kB     00:00
(18/27): python3.12-cffi-1.16.0-2.el9.x86_64.rpm                                                                                                                                 5.6 MB/s | 297 kB     00:00
(19/27): python3.12-idna-3.4-2.el9.noarch.rpm                                                                                                                                    1.5 MB/s | 104 kB     00:00
(20/27): python3.12-cryptography-41.0.7-3.el9.x86_64.rpm                                                                                                                         3.8 MB/s | 1.2 MB     00:00
(21/27): python3.12-pip-wheel-23.2.1-5.el9.noarch.rpm                                                                                                                            5.0 MB/s | 1.5 MB     00:00
(22/27): python3.12-ply-3.11-2.el9.noarch.rpm                                                                                                                                    4.5 MB/s | 131 kB     00:00
(23/27): python3.12-pycparser-2.20-2.el9.noarch.rpm                                                                                                                              1.5 MB/s | 143 kB     00:00
(24/27): python3.12-pyyaml-6.0.1-2.el9.x86_64.rpm                                                                                                                                2.8 MB/s | 208 kB     00:00
(25/27): etcd-3.7.2-1PGDG.rhel9.6.x86_64.rpm                                                                                                                                      13 MB/s |  17 MB     00:01
(26/27): python3.12-urllib3-1.26.19-3.el9_8.noarch.rpm                                                                                                                           836 kB/s | 258 kB     00:00
(27/27): python3.12-libs-3.12.13-2.el9_8.x86_64.rpm                                                                                                                              8.4 MB/s | 9.2 MB     00:01
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Total                                                                                                                                                                             16 MB/s |  33 MB     00:02
Running transaction check
Transaction check succeeded.
Running transaction test
Transaction test succeeded.
Running transaction
  Preparing        :                                                                                                                                                                                         1/1
  Installing       : python3.12-pip-wheel-23.2.1-5.el9.noarch                                                                                                                                               1/27
  Installing       : mpdecimal-2.5.1-3.el9.x86_64                                                                                                                                                           2/27
  Installing       : libnsl2-2.0.0-1.el9.0.1.x86_64                                                                                                                                                         3/27
  Installing       : python3.12-3.12.13-2.el9_8.x86_64                                                                                                                                                      4/27
  Installing       : python3.12-libs-3.12.13-2.el9_8.x86_64                                                                                                                                                 5/27
  Installing       : python3.12-dns-2.8.0-45PGDG.rhel9.6.noarch                                                                                                                                             6/27
  Installing       : python3.12-six-1.17.0-1PGDG.rhel9.noarch                                                                                                                                               7/27
  Installing       : python3.12-dateutil-2.9.0.post0-7PGDG.rhel9.6.noarch                                                                                                                                   8/27
  Installing       : py-consul-1.6.0-44PGDG.rhel9.noarch                                                                                                                                                    9/27
  Installing       : python3-ydiff-1.4.2-46PGDG.rhel9.noarch                                                                                                                                               10/27
  Installing       : python3.12-click-8.1.7-43PGDG.rhel9.noarch                                                                                                                                            11/27
  Installing       : python3.12-prettytable-3.4.0-43PGDG.rhel9.noarch                                                                                                                                      12/27
  Installing       : python3.12-psutil-6.1.1-42PGDG.rhel9.x86_64                                                                                                                                           13/27
  Installing       : python3.12-psycopg2-2.9.10-1PGDG.rhel9.x86_64                                                                                                                                         14/27
  Installing       : python3.12-systemd-235-42PGDG.rhel9.6.x86_64                                                                                                                                          15/27
  Installing       : python3.12-wcwidth-0.2.13-2PGDG.rhel9.noarch                                                                                                                                          16/27
  Installing       : python3.12-idna-3.4-2.el9.noarch                                                                                                                                                      17/27
  Installing       : python3.12-urllib3-1.26.19-3.el9_8.noarch                                                                                                                                             18/27
  Installing       : python3.12-etcd-0.4.5-48PGDG.rhel9.noarch                                                                                                                                             19/27
  Installing       : python3.12-ply-3.11-2.el9.noarch                                                                                                                                                      20/27
  Installing       : python3.12-pycparser-2.20-2.el9.noarch                                                                                                                                                21/27
  Installing       : python3.12-cffi-1.16.0-2.el9.x86_64                                                                                                                                                   22/27
  Installing       : python3.12-cryptography-41.0.7-3.el9.x86_64                                                                                                                                           23/27
  Installing       : python3.12-pyyaml-6.0.1-2.el9.x86_64                                                                                                                                                  24/27
  Installing       : patroni-4.1.5-1PGDG.rhel9.6.noarch                                                                                                                                                    25/27
  Running scriptlet: patroni-4.1.5-1PGDG.rhel9.6.noarch                                                                                                                                                    25/27
  Installing       : patroni-etcd-4.1.5-1PGDG.rhel9.6.noarch                                                                                                                                               26/27
  Running scriptlet: etcd-3.7.2-1PGDG.rhel9.6.x86_64                                                                                                                                                       27/27
Creating group 'etcd' with GID 989.
Creating user 'etcd' (etcd User) with UID 989 and GID 989.

  Installing       : etcd-3.7.2-1PGDG.rhel9.6.x86_64                                                                                                                                                       27/27
  Running scriptlet: etcd-3.7.2-1PGDG.rhel9.6.x86_64                                                                                                                                                       27/27
  Verifying        : patroni-4.1.5-1PGDG.rhel9.6.noarch                                                                                                                                                     1/27
  Verifying        : patroni-etcd-4.1.5-1PGDG.rhel9.6.noarch                                                                                                                                                2/27
  Verifying        : py-consul-1.6.0-44PGDG.rhel9.noarch                                                                                                                                                    3/27
  Verifying        : python3-ydiff-1.4.2-46PGDG.rhel9.noarch                                                                                                                                                4/27
  Verifying        : python3.12-click-8.1.7-43PGDG.rhel9.noarch                                                                                                                                             5/27
  Verifying        : python3.12-dateutil-2.9.0.post0-7PGDG.rhel9.6.noarch                                                                                                                                   6/27
  Verifying        : python3.12-dns-2.8.0-45PGDG.rhel9.6.noarch                                                                                                                                             7/27
  Verifying        : python3.12-etcd-0.4.5-48PGDG.rhel9.noarch                                                                                                                                              8/27
  Verifying        : python3.12-prettytable-3.4.0-43PGDG.rhel9.noarch                                                                                                                                       9/27
  Verifying        : python3.12-psutil-6.1.1-42PGDG.rhel9.x86_64                                                                                                                                           10/27
  Verifying        : python3.12-psycopg2-2.9.10-1PGDG.rhel9.x86_64                                                                                                                                         11/27
  Verifying        : python3.12-six-1.17.0-1PGDG.rhel9.noarch                                                                                                                                              12/27
  Verifying        : python3.12-systemd-235-42PGDG.rhel9.6.x86_64                                                                                                                                          13/27
  Verifying        : python3.12-wcwidth-0.2.13-2PGDG.rhel9.noarch                                                                                                                                          14/27
  Verifying        : etcd-3.7.2-1PGDG.rhel9.6.x86_64                                                                                                                                                       15/27
  Verifying        : libnsl2-2.0.0-1.el9.0.1.x86_64                                                                                                                                                        16/27
  Verifying        : mpdecimal-2.5.1-3.el9.x86_64                                                                                                                                                          17/27
  Verifying        : python3.12-3.12.13-2.el9_8.x86_64                                                                                                                                                     18/27
  Verifying        : python3.12-cffi-1.16.0-2.el9.x86_64                                                                                                                                                   19/27
  Verifying        : python3.12-cryptography-41.0.7-3.el9.x86_64                                                                                                                                           20/27
  Verifying        : python3.12-idna-3.4-2.el9.noarch                                                                                                                                                      21/27
  Verifying        : python3.12-libs-3.12.13-2.el9_8.x86_64                                                                                                                                                22/27
  Verifying        : python3.12-pip-wheel-23.2.1-5.el9.noarch                                                                                                                                              23/27
  Verifying        : python3.12-ply-3.11-2.el9.noarch                                                                                                                                                      24/27
  Verifying        : python3.12-pycparser-2.20-2.el9.noarch                                                                                                                                                25/27
  Verifying        : python3.12-pyyaml-6.0.1-2.el9.x86_64                                                                                                                                                  26/27
  Verifying        : python3.12-urllib3-1.26.19-3.el9_8.noarch                                                                                                                                             27/27

Installed:
  etcd-3.7.2-1PGDG.rhel9.6.x86_64                   libnsl2-2.0.0-1.el9.0.1.x86_64                 mpdecimal-2.5.1-3.el9.x86_64                         patroni-4.1.5-1PGDG.rhel9.6.noarch
  patroni-etcd-4.1.5-1PGDG.rhel9.6.noarch           py-consul-1.6.0-44PGDG.rhel9.noarch            python3-ydiff-1.4.2-46PGDG.rhel9.noarch              python3.12-3.12.13-2.el9_8.x86_64
  python3.12-cffi-1.16.0-2.el9.x86_64               python3.12-click-8.1.7-43PGDG.rhel9.noarch     python3.12-cryptography-41.0.7-3.el9.x86_64          python3.12-dateutil-2.9.0.post0-7PGDG.rhel9.6.noarch
  python3.12-dns-2.8.0-45PGDG.rhel9.6.noarch        python3.12-etcd-0.4.5-48PGDG.rhel9.noarch      python3.12-idna-3.4-2.el9.noarch                     python3.12-libs-3.12.13-2.el9_8.x86_64
  python3.12-pip-wheel-23.2.1-5.el9.noarch          python3.12-ply-3.11-2.el9.noarch               python3.12-prettytable-3.4.0-43PGDG.rhel9.noarch     python3.12-psutil-6.1.1-42PGDG.rhel9.x86_64
  python3.12-psycopg2-2.9.10-1PGDG.rhel9.x86_64     python3.12-pycparser-2.20-2.el9.noarch         python3.12-pyyaml-6.0.1-2.el9.x86_64                 python3.12-six-1.17.0-1PGDG.rhel9.noarch
  python3.12-systemd-235-42PGDG.rhel9.6.x86_64      python3.12-urllib3-1.26.19-3.el9_8.noarch      python3.12-wcwidth-0.2.13-2PGDG.rhel9.noarch

Complete!
[root@db1 ~]# etcd --version; patroni --version
etcd Version: 3.7.2
Git SHA: 68c065e
Go Version: go1.26.8
Go OS/Arch: linux/amd64
patroni 4.1.5

-- db2 
[root@db2 ~]# dnf install -y epel-release
Last metadata expiration check: 1:55:53 ago on Sat 17 Oct 2026 01:26:33 PM WEST.
Dependencies resolved.
=================================================================================================================================================================================================================
 Package                                               Architecture                                    Version                                             Repository                                       Size
=================================================================================================================================================================================================================
Installing:
 epel-release                                          noarch                                          9-10.el9                                            extras                                           19 k

Transaction Summary
=================================================================================================================================================================================================================
Install  1 Package

Total download size: 19 k
Installed size: 26 k
Downloading Packages:
epel-release-9-10.el9.noarch.rpm                                                                                                                                                 293 kB/s |  19 kB     00:00
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Total                                                                                                                                                                             53 kB/s |  19 kB     00:00
Running transaction check
Transaction check succeeded.
Running transaction test
Transaction test succeeded.
Running transaction
  Preparing        :                                                                                                                                                                                         1/1
  Installing       : epel-release-9-10.el9.noarch                                                                                                                                                            1/1
  Running scriptlet: epel-release-9-10.el9.noarch                                                                                                                                                            1/1
Many EPEL packages require the CodeReady Builder (CRB) repository.
It is recommended that you run /usr/bin/crb enable to enable the CRB repository.

  Verifying        : epel-release-9-10.el9.noarch                                                                                                                                                            1/1

Installed:
  epel-release-9-10.el9.noarch

Complete!
[root@db2 ~]# dnf --enablerepo=pgdg-rhel9-extras install -y etcd patroni patroni-etcd
Extra Packages for Enterprise Linux 9 - x86_64                                                                                                                                   7.2 MB/s |  20 MB     00:02
Extra Packages for Enterprise Linux 9 openh264 (From Cisco) - x86_64                                                                                                             2.8 kB/s | 2.5 kB     00:00
Extra packages to support some RPMs in the PostgreSQL RPM repo for RHEL / Rocky Linux / AlmaLinux 9.6 - x86_64                                                                   2.0 kB/s | 659  B     00:00
Extra packages to support some RPMs in the PostgreSQL RPM repo for RHEL / Rocky Linux / AlmaLinux 9.6 - x86_64                                                                   305 kB/s | 2.4 kB     00:00
Importing GPG key 0x08B40D20:
 Userid     : "PostgreSQL RPM Repository <pgsql-pkg-yum@lists.postgresql.org>"
 Fingerprint: D4BF 08AE 67A0 B4C7 A1DB CCD2 40BC A2B4 08B4 0D20
 From       : /etc/pki/rpm-gpg/PGDG-RPM-GPG-KEY-RHEL
Extra packages to support some RPMs in the PostgreSQL RPM repo for RHEL / Rocky Linux / AlmaLinux 9.6 - x86_64                                                                    98 kB/s |  47 kB     00:00
Dependencies resolved.
=================================================================================================================================================================================================================
 Package                                                Architecture                          Version                                                     Repository                                        Size
=================================================================================================================================================================================================================
Installing:
 etcd                                                   x86_64                                3.7.2-1PGDG.rhel9.6                                         pgdg-rhel9-extras                                 17 M
 patroni                                                noarch                                4.1.5-1PGDG.rhel9.6                                         pgdg-common                                      1.4 M
 patroni-etcd                                           noarch                                4.1.5-1PGDG.rhel9.6                                         pgdg-common                                       10 k
Installing dependencies:
 libnsl2                                                x86_64                                2.0.0-1.el9.0.1                                             appstream                                         30 k
 mpdecimal                                              x86_64                                2.5.1-3.el9                                                 appstream                                         85 k
 py-consul                                              noarch                                1.6.0-44PGDG.rhel9                                          pgdg-common                                       64 k
 python3-ydiff                                          noarch                                1.4.2-46PGDG.rhel9                                          pgdg-common                                       36 k
 python3.12                                             x86_64                                3.12.13-2.el9_8                                             appstream                                         26 k
 python3.12-cffi                                        x86_64                                1.16.0-2.el9                                                appstream                                        297 k
 python3.12-click                                       noarch                                8.1.7-43PGDG.rhel9                                          pgdg-common                                      226 k
 python3.12-cryptography                                x86_64                                41.0.7-3.el9                                                appstream                                        1.2 M
 python3.12-dateutil                                    noarch                                2.9.0.post0-7PGDG.rhel9.6                                   pgdg-common                                      328 k
 python3.12-dns                                         noarch                                2.8.0-45PGDG.rhel9.6                                        pgdg-common                                      586 k
 python3.12-etcd                                        noarch                                0.4.5-48PGDG.rhel9                                          pgdg-common                                       98 k
 python3.12-idna                                        noarch                                3.4-2.el9                                                   appstream                                        104 k
 python3.12-libs                                        x86_64                                3.12.13-2.el9_8                                             appstream                                        9.2 M
 python3.12-pip-wheel                                   noarch                                23.2.1-5.el9                                                appstream                                        1.5 M
 python3.12-ply                                         noarch                                3.11-2.el9                                                  appstream                                        131 k
 python3.12-prettytable                                 noarch                                3.4.0-43PGDG.rhel9                                          pgdg-common                                       66 k
 python3.12-psutil                                      x86_64                                6.1.1-42PGDG.rhel9                                          pgdg-common                                      262 k
 python3.12-psycopg2                                    x86_64                                2.9.10-1PGDG.rhel9                                          pgdg-common                                      202 k
 python3.12-pycparser                                   noarch                                2.20-2.el9                                                  appstream                                        143 k
 python3.12-pyyaml                                      x86_64                                6.0.1-2.el9                                                 appstream                                        208 k
 python3.12-six                                         noarch                                1.17.0-1PGDG.rhel9                                          pgdg-common                                       40 k
 python3.12-systemd                                     x86_64                                235-42PGDG.rhel9.6                                          pgdg-common                                      100 k
 python3.12-urllib3                                     noarch                                1.26.19-3.el9_8                                             appstream                                        258 k
 python3.12-wcwidth                                     noarch                                0.2.13-2PGDG.rhel9                                          pgdg-common                                       46 k

Transaction Summary
=================================================================================================================================================================================================================
Install  27 Packages

Total download size: 33 M
Installed size: 124 M
Downloading Packages:
(1/27): patroni-etcd-4.1.5-1PGDG.rhel9.6.noarch.rpm                                                                                                                               55 kB/s |  10 kB     00:00
(2/27): py-consul-1.6.0-44PGDG.rhel9.noarch.rpm                                                                                                                                  271 kB/s |  64 kB     00:00
(3/27): python3-ydiff-1.4.2-46PGDG.rhel9.noarch.rpm                                                                                                                              473 kB/s |  36 kB     00:00
(4/27): patroni-4.1.5-1PGDG.rhel9.6.noarch.rpm                                                                                                                                   4.7 MB/s | 1.4 MB     00:00
(5/27): python3.12-click-8.1.7-43PGDG.rhel9.noarch.rpm                                                                                                                           4.8 MB/s | 226 kB     00:00
(6/27): python3.12-dateutil-2.9.0.post0-7PGDG.rhel9.6.noarch.rpm                                                                                                                 8.1 MB/s | 328 kB     00:00
(7/27): python3.12-dns-2.8.0-45PGDG.rhel9.6.noarch.rpm                                                                                                                            17 MB/s | 586 kB     00:00
(8/27): python3.12-etcd-0.4.5-48PGDG.rhel9.noarch.rpm                                                                                                                            3.1 MB/s |  98 kB     00:00
(9/27): python3.12-prettytable-3.4.0-43PGDG.rhel9.noarch.rpm                                                                                                                     2.6 MB/s |  66 kB     00:00
(10/27): python3.12-psutil-6.1.1-42PGDG.rhel9.x86_64.rpm                                                                                                                         6.4 MB/s | 262 kB     00:00
(11/27): python3.12-psycopg2-2.9.10-1PGDG.rhel9.x86_64.rpm                                                                                                                       4.2 MB/s | 202 kB     00:00
(12/27): python3.12-six-1.17.0-1PGDG.rhel9.noarch.rpm                                                                                                                            893 kB/s |  40 kB     00:00
(13/27): python3.12-systemd-235-42PGDG.rhel9.6.x86_64.rpm                                                                                                                        2.8 MB/s | 100 kB     00:00
(14/27): python3.12-wcwidth-0.2.13-2PGDG.rhel9.noarch.rpm                                                                                                                        1.9 MB/s |  46 kB     00:00
(15/27): libnsl2-2.0.0-1.el9.0.1.x86_64.rpm                                                                                                                                      207 kB/s |  30 kB     00:00
(16/27): mpdecimal-2.5.1-3.el9.x86_64.rpm                                                                                                                                        573 kB/s |  85 kB     00:00
(17/27): python3.12-3.12.13-2.el9_8.x86_64.rpm                                                                                                                                   526 kB/s |  26 kB     00:00
(18/27): python3.12-cffi-1.16.0-2.el9.x86_64.rpm                                                                                                                                 3.1 MB/s | 297 kB     00:00
(19/27): python3.12-idna-3.4-2.el9.noarch.rpm                                                                                                                                    1.4 MB/s | 104 kB     00:00
(20/27): python3.12-cryptography-41.0.7-3.el9.x86_64.rpm                                                                                                                         4.9 MB/s | 1.2 MB     00:00
(21/27): python3.12-pip-wheel-23.2.1-5.el9.noarch.rpm                                                                                                                            4.8 MB/s | 1.5 MB     00:00
(22/27): python3.12-ply-3.11-2.el9.noarch.rpm                                                                                                                                    2.1 MB/s | 131 kB     00:00
(23/27): etcd-3.7.2-1PGDG.rhel9.6.x86_64.rpm                                                                                                                                      14 MB/s |  17 MB     00:01
(24/27): python3.12-pycparser-2.20-2.el9.noarch.rpm                                                                                                                              354 kB/s | 143 kB     00:00
(25/27): python3.12-pyyaml-6.0.1-2.el9.x86_64.rpm                                                                                                                                5.7 MB/s | 208 kB     00:00
(26/27): python3.12-urllib3-1.26.19-3.el9_8.noarch.rpm                                                                                                                           3.4 MB/s | 258 kB     00:00
(27/27): python3.12-libs-3.12.13-2.el9_8.x86_64.rpm                                                                                                                              7.3 MB/s | 9.2 MB     00:01
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Total                                                                                                                                                                             14 MB/s |  33 MB     00:02
Running transaction check
Transaction check succeeded.
Running transaction test
Transaction test succeeded.
Running transaction
  Preparing        :                                                                                                                                                                                         1/1
  Installing       : python3.12-pip-wheel-23.2.1-5.el9.noarch                                                                                                                                               1/27
  Installing       : mpdecimal-2.5.1-3.el9.x86_64                                                                                                                                                           2/27
  Installing       : libnsl2-2.0.0-1.el9.0.1.x86_64                                                                                                                                                         3/27
  Installing       : python3.12-3.12.13-2.el9_8.x86_64                                                                                                                                                      4/27
  Installing       : python3.12-libs-3.12.13-2.el9_8.x86_64                                                                                                                                                 5/27
  Installing       : python3.12-dns-2.8.0-45PGDG.rhel9.6.noarch                                                                                                                                             6/27
  Installing       : python3.12-six-1.17.0-1PGDG.rhel9.noarch                                                                                                                                               7/27
  Installing       : python3.12-dateutil-2.9.0.post0-7PGDG.rhel9.6.noarch                                                                                                                                   8/27
  Installing       : py-consul-1.6.0-44PGDG.rhel9.noarch                                                                                                                                                    9/27
  Installing       : python3-ydiff-1.4.2-46PGDG.rhel9.noarch                                                                                                                                               10/27
  Installing       : python3.12-click-8.1.7-43PGDG.rhel9.noarch                                                                                                                                            11/27
  Installing       : python3.12-prettytable-3.4.0-43PGDG.rhel9.noarch                                                                                                                                      12/27
  Installing       : python3.12-psutil-6.1.1-42PGDG.rhel9.x86_64                                                                                                                                           13/27
  Installing       : python3.12-psycopg2-2.9.10-1PGDG.rhel9.x86_64                                                                                                                                         14/27
  Installing       : python3.12-systemd-235-42PGDG.rhel9.6.x86_64                                                                                                                                          15/27
  Installing       : python3.12-wcwidth-0.2.13-2PGDG.rhel9.noarch                                                                                                                                          16/27
  Installing       : python3.12-idna-3.4-2.el9.noarch                                                                                                                                                      17/27
  Installing       : python3.12-urllib3-1.26.19-3.el9_8.noarch                                                                                                                                             18/27
  Installing       : python3.12-etcd-0.4.5-48PGDG.rhel9.noarch                                                                                                                                             19/27
  Installing       : python3.12-ply-3.11-2.el9.noarch                                                                                                                                                      20/27
  Installing       : python3.12-pycparser-2.20-2.el9.noarch                                                                                                                                                21/27
  Installing       : python3.12-cffi-1.16.0-2.el9.x86_64                                                                                                                                                   22/27
  Installing       : python3.12-cryptography-41.0.7-3.el9.x86_64                                                                                                                                           23/27
  Installing       : python3.12-pyyaml-6.0.1-2.el9.x86_64                                                                                                                                                  24/27
  Installing       : patroni-4.1.5-1PGDG.rhel9.6.noarch                                                                                                                                                    25/27
  Running scriptlet: patroni-4.1.5-1PGDG.rhel9.6.noarch                                                                                                                                                    25/27
  Installing       : patroni-etcd-4.1.5-1PGDG.rhel9.6.noarch                                                                                                                                               26/27
  Running scriptlet: etcd-3.7.2-1PGDG.rhel9.6.x86_64                                                                                                                                                       27/27
Creating group 'etcd' with GID 989.
Creating user 'etcd' (etcd User) with UID 989 and GID 989.

  Installing       : etcd-3.7.2-1PGDG.rhel9.6.x86_64                                                                                                                                                       27/27
  Running scriptlet: etcd-3.7.2-1PGDG.rhel9.6.x86_64                                                                                                                                                       27/27
  Verifying        : patroni-4.1.5-1PGDG.rhel9.6.noarch                                                                                                                                                     1/27
  Verifying        : patroni-etcd-4.1.5-1PGDG.rhel9.6.noarch                                                                                                                                                2/27
  Verifying        : py-consul-1.6.0-44PGDG.rhel9.noarch                                                                                                                                                    3/27
  Verifying        : python3-ydiff-1.4.2-46PGDG.rhel9.noarch                                                                                                                                                4/27
  Verifying        : python3.12-click-8.1.7-43PGDG.rhel9.noarch                                                                                                                                             5/27
  Verifying        : python3.12-dateutil-2.9.0.post0-7PGDG.rhel9.6.noarch                                                                                                                                   6/27
  Verifying        : python3.12-dns-2.8.0-45PGDG.rhel9.6.noarch                                                                                                                                             7/27
  Verifying        : python3.12-etcd-0.4.5-48PGDG.rhel9.noarch                                                                                                                                              8/27
  Verifying        : python3.12-prettytable-3.4.0-43PGDG.rhel9.noarch                                                                                                                                       9/27
  Verifying        : python3.12-psutil-6.1.1-42PGDG.rhel9.x86_64                                                                                                                                           10/27
  Verifying        : python3.12-psycopg2-2.9.10-1PGDG.rhel9.x86_64                                                                                                                                         11/27
  Verifying        : python3.12-six-1.17.0-1PGDG.rhel9.noarch                                                                                                                                              12/27
  Verifying        : python3.12-systemd-235-42PGDG.rhel9.6.x86_64                                                                                                                                          13/27
  Verifying        : python3.12-wcwidth-0.2.13-2PGDG.rhel9.noarch                                                                                                                                          14/27
  Verifying        : etcd-3.7.2-1PGDG.rhel9.6.x86_64                                                                                                                                                       15/27
  Verifying        : libnsl2-2.0.0-1.el9.0.1.x86_64                                                                                                                                                        16/27
  Verifying        : mpdecimal-2.5.1-3.el9.x86_64                                                                                                                                                          17/27
  Verifying        : python3.12-3.12.13-2.el9_8.x86_64                                                                                                                                                     18/27
  Verifying        : python3.12-cffi-1.16.0-2.el9.x86_64                                                                                                                                                   19/27
  Verifying        : python3.12-cryptography-41.0.7-3.el9.x86_64                                                                                                                                           20/27
  Verifying        : python3.12-idna-3.4-2.el9.noarch                                                                                                                                                      21/27
  Verifying        : python3.12-libs-3.12.13-2.el9_8.x86_64                                                                                                                                                22/27
  Verifying        : python3.12-pip-wheel-23.2.1-5.el9.noarch                                                                                                                                              23/27
  Verifying        : python3.12-ply-3.11-2.el9.noarch                                                                                                                                                      24/27
  Verifying        : python3.12-pycparser-2.20-2.el9.noarch                                                                                                                                                25/27
  Verifying        : python3.12-pyyaml-6.0.1-2.el9.x86_64                                                                                                                                                  26/27
  Verifying        : python3.12-urllib3-1.26.19-3.el9_8.noarch                                                                                                                                             27/27

Installed:
  etcd-3.7.2-1PGDG.rhel9.6.x86_64                   libnsl2-2.0.0-1.el9.0.1.x86_64                 mpdecimal-2.5.1-3.el9.x86_64                         patroni-4.1.5-1PGDG.rhel9.6.noarch
  patroni-etcd-4.1.5-1PGDG.rhel9.6.noarch           py-consul-1.6.0-44PGDG.rhel9.noarch            python3-ydiff-1.4.2-46PGDG.rhel9.noarch              python3.12-3.12.13-2.el9_8.x86_64
  python3.12-cffi-1.16.0-2.el9.x86_64               python3.12-click-8.1.7-43PGDG.rhel9.noarch     python3.12-cryptography-41.0.7-3.el9.x86_64          python3.12-dateutil-2.9.0.post0-7PGDG.rhel9.6.noarch
  python3.12-dns-2.8.0-45PGDG.rhel9.6.noarch        python3.12-etcd-0.4.5-48PGDG.rhel9.noarch      python3.12-idna-3.4-2.el9.noarch                     python3.12-libs-3.12.13-2.el9_8.x86_64
  python3.12-pip-wheel-23.2.1-5.el9.noarch          python3.12-ply-3.11-2.el9.noarch               python3.12-prettytable-3.4.0-43PGDG.rhel9.noarch     python3.12-psutil-6.1.1-42PGDG.rhel9.x86_64
  python3.12-psycopg2-2.9.10-1PGDG.rhel9.x86_64     python3.12-pycparser-2.20-2.el9.noarch         python3.12-pyyaml-6.0.1-2.el9.x86_64                 python3.12-six-1.17.0-1PGDG.rhel9.noarch
  python3.12-systemd-235-42PGDG.rhel9.6.x86_64      python3.12-urllib3-1.26.19-3.el9_8.noarch      python3.12-wcwidth-0.2.13-2PGDG.rhel9.noarch

Complete!
[root@db2 ~]# etcd --version; patroni --version
etcd Version: 3.7.2
Git SHA: 68c065e
Go Version: go1.26.8
Go OS/Arch: linux/amd64
patroni 4.1.5

-- db3 
[root@db3 ~]# sudo dnf install -y epel-release
Last metadata expiration check: 3:22:24 ago on Sat 17 Oct 2026 12:02:26 PM WEST.
Dependencies resolved.
=================================================================================================================================================================================================================
 Package                                               Architecture                                    Version                                             Repository                                       Size
=================================================================================================================================================================================================================
Installing:
 epel-release                                          noarch                                          9-10.el9                                            extras                                           19 k

Transaction Summary
=================================================================================================================================================================================================================
Install  1 Package

Total download size: 19 k
Installed size: 26 k
Downloading Packages:
epel-release-9-10.el9.noarch.rpm                                                                                                                                                 341 kB/s |  19 kB     00:00
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Total                                                                                                                                                                             66 kB/s |  19 kB     00:00
Running transaction check
Transaction check succeeded.
Running transaction test
Transaction test succeeded.
Running transaction
  Preparing        :                                                                                                                                                                                         1/1
  Installing       : epel-release-9-10.el9.noarch                                                                                                                                                            1/1
  Running scriptlet: epel-release-9-10.el9.noarch                                                                                                                                                            1/1
Many EPEL packages require the CodeReady Builder (CRB) repository.
It is recommended that you run /usr/bin/crb enable to enable the CRB repository.

  Verifying        : epel-release-9-10.el9.noarch                                                                                                                                                            1/1

Installed:
  epel-release-9-10.el9.noarch

Complete!
[root@db3 ~]# sudo dnf --enablerepo=pgdg-rhel9-extras install -y etcd patroni patroni-etcd
Extra Packages for Enterprise Linux 9 - x86_64                                                                                                                                   6.2 MB/s |  20 MB     00:03
Extra Packages for Enterprise Linux 9 openh264 (From Cisco) - x86_64                                                                                                             2.7 kB/s | 2.5 kB     00:00
Extra packages to support some RPMs in the PostgreSQL RPM repo for RHEL / Rocky Linux / AlmaLinux 9.6 - x86_64                                                                   1.9 kB/s | 659  B     00:00
Extra packages to support some RPMs in the PostgreSQL RPM repo for RHEL / Rocky Linux / AlmaLinux 9.6 - x86_64                                                                   148 kB/s | 2.4 kB     00:00
Importing GPG key 0x08B40D20:
 Userid     : "PostgreSQL RPM Repository <pgsql-pkg-yum@lists.postgresql.org>"
 Fingerprint: D4BF 08AE 67A0 B4C7 A1DB CCD2 40BC A2B4 08B4 0D20
 From       : /etc/pki/rpm-gpg/PGDG-RPM-GPG-KEY-RHEL
Extra packages to support some RPMs in the PostgreSQL RPM repo for RHEL / Rocky Linux / AlmaLinux 9.6 - x86_64                                                                   112 kB/s |  47 kB     00:00
Dependencies resolved.
=================================================================================================================================================================================================================
 Package                                                Architecture                          Version                                                     Repository                                        Size
=================================================================================================================================================================================================================
Installing:
 etcd                                                   x86_64                                3.7.2-1PGDG.rhel9.6                                         pgdg-rhel9-extras                                 17 M
 patroni                                                noarch                                4.1.5-1PGDG.rhel9.6                                         pgdg-common                                      1.4 M
 patroni-etcd                                           noarch                                4.1.5-1PGDG.rhel9.6                                         pgdg-common                                       10 k
Installing dependencies:
 libnsl2                                                x86_64                                2.0.0-1.el9.0.1                                             appstream                                         30 k
 mpdecimal                                              x86_64                                2.5.1-3.el9                                                 appstream                                         85 k
 py-consul                                              noarch                                1.6.0-44PGDG.rhel9                                          pgdg-common                                       64 k
 python3-ydiff                                          noarch                                1.4.2-46PGDG.rhel9                                          pgdg-common                                       36 k
 python3.12                                             x86_64                                3.12.13-2.el9_8                                             appstream                                         26 k
 python3.12-cffi                                        x86_64                                1.16.0-2.el9                                                appstream                                        297 k
 python3.12-click                                       noarch                                8.1.7-43PGDG.rhel9                                          pgdg-common                                      226 k
 python3.12-cryptography                                x86_64                                41.0.7-3.el9                                                appstream                                        1.2 M
 python3.12-dateutil                                    noarch                                2.9.0.post0-7PGDG.rhel9.6                                   pgdg-common                                      328 k
 python3.12-dns                                         noarch                                2.8.0-45PGDG.rhel9.6                                        pgdg-common                                      586 k
 python3.12-etcd                                        noarch                                0.4.5-48PGDG.rhel9                                          pgdg-common                                       98 k
 python3.12-idna                                        noarch                                3.4-2.el9                                                   appstream                                        104 k
 python3.12-libs                                        x86_64                                3.12.13-2.el9_8                                             appstream                                        9.2 M
 python3.12-pip-wheel                                   noarch                                23.2.1-5.el9                                                appstream                                        1.5 M
 python3.12-ply                                         noarch                                3.11-2.el9                                                  appstream                                        131 k
 python3.12-prettytable                                 noarch                                3.4.0-43PGDG.rhel9                                          pgdg-common                                       66 k
 python3.12-psutil                                      x86_64                                6.1.1-42PGDG.rhel9                                          pgdg-common                                      262 k
 python3.12-psycopg2                                    x86_64                                2.9.10-1PGDG.rhel9                                          pgdg-common                                      202 k
 python3.12-pycparser                                   noarch                                2.20-2.el9                                                  appstream                                        143 k
 python3.12-pyyaml                                      x86_64                                6.0.1-2.el9                                                 appstream                                        208 k
 python3.12-six                                         noarch                                1.17.0-1PGDG.rhel9                                          pgdg-common                                       40 k
 python3.12-systemd                                     x86_64                                235-42PGDG.rhel9.6                                          pgdg-common                                      100 k
 python3.12-urllib3                                     noarch                                1.26.19-3.el9_8                                             appstream                                        258 k
 python3.12-wcwidth                                     noarch                                0.2.13-2PGDG.rhel9                                          pgdg-common                                       46 k

Transaction Summary
=================================================================================================================================================================================================================
Install  27 Packages

Total download size: 33 M
Installed size: 124 M
Downloading Packages:
(1/27): patroni-etcd-4.1.5-1PGDG.rhel9.6.noarch.rpm                                                                                                                               73 kB/s |  10 kB     00:00
(2/27): patroni-4.1.5-1PGDG.rhel9.6.noarch.rpm                                                                                                                                   6.0 MB/s | 1.4 MB     00:00
(3/27): python3-ydiff-1.4.2-46PGDG.rhel9.noarch.rpm                                                                                                                              367 kB/s |  36 kB     00:00
(4/27): py-consul-1.6.0-44PGDG.rhel9.noarch.rpm                                                                                                                                  235 kB/s |  64 kB     00:00
(5/27): python3.12-click-8.1.7-43PGDG.rhel9.noarch.rpm                                                                                                                           4.0 MB/s | 226 kB     00:00
(6/27): python3.12-dateutil-2.9.0.post0-7PGDG.rhel9.6.noarch.rpm                                                                                                                 3.2 MB/s | 328 kB     00:00
(7/27): python3.12-dns-2.8.0-45PGDG.rhel9.6.noarch.rpm                                                                                                                           5.7 MB/s | 586 kB     00:00
(8/27): python3.12-etcd-0.4.5-48PGDG.rhel9.noarch.rpm                                                                                                                            1.1 MB/s |  98 kB     00:00
(9/27): python3.12-prettytable-3.4.0-43PGDG.rhel9.noarch.rpm                                                                                                                     1.1 MB/s |  66 kB     00:00
(10/27): python3.12-psutil-6.1.1-42PGDG.rhel9.x86_64.rpm                                                                                                                         5.4 MB/s | 262 kB     00:00
(11/27): python3.12-psycopg2-2.9.10-1PGDG.rhel9.x86_64.rpm                                                                                                                       3.8 MB/s | 202 kB     00:00
(12/27): python3.12-six-1.17.0-1PGDG.rhel9.noarch.rpm                                                                                                                            666 kB/s |  40 kB     00:00
(13/27): python3.12-systemd-235-42PGDG.rhel9.6.x86_64.rpm                                                                                                                        1.7 MB/s | 100 kB     00:00
(14/27): python3.12-wcwidth-0.2.13-2PGDG.rhel9.noarch.rpm                                                                                                                        1.1 MB/s |  46 kB     00:00
(15/27): mpdecimal-2.5.1-3.el9.x86_64.rpm                                                                                                                                        891 kB/s |  85 kB     00:00
(16/27): libnsl2-2.0.0-1.el9.0.1.x86_64.rpm                                                                                                                                      222 kB/s |  30 kB     00:00
(17/27): python3.12-3.12.13-2.el9_8.x86_64.rpm                                                                                                                                   630 kB/s |  26 kB     00:00
(18/27): python3.12-cffi-1.16.0-2.el9.x86_64.rpm                                                                                                                                 2.7 MB/s | 297 kB     00:00
(19/27): python3.12-idna-3.4-2.el9.noarch.rpm                                                                                                                                    1.1 MB/s | 104 kB     00:00
(20/27): python3.12-cryptography-41.0.7-3.el9.x86_64.rpm                                                                                                                         3.4 MB/s | 1.2 MB     00:00
(21/27): python3.12-pip-wheel-23.2.1-5.el9.noarch.rpm                                                                                                                            4.2 MB/s | 1.5 MB     00:00
(22/27): etcd-3.7.2-1PGDG.rhel9.6.x86_64.rpm                                                                                                                                      15 MB/s |  17 MB     00:01
(23/27): python3.12-ply-3.11-2.el9.noarch.rpm                                                                                                                                    546 kB/s | 131 kB     00:00
(24/27): python3.12-pyyaml-6.0.1-2.el9.x86_64.rpm                                                                                                                                5.8 MB/s | 208 kB     00:00
(25/27): python3.12-pycparser-2.20-2.el9.noarch.rpm                                                                                                                              1.2 MB/s | 143 kB     00:00
(26/27): python3.12-urllib3-1.26.19-3.el9_8.noarch.rpm                                                                                                                           3.7 MB/s | 258 kB     00:00
(27/27): python3.12-libs-3.12.13-2.el9_8.x86_64.rpm                                                                                                                              8.0 MB/s | 9.2 MB     00:01
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Total                                                                                                                                                                             14 MB/s |  33 MB     00:02
Running transaction check
Transaction check succeeded.
Running transaction test
Transaction test succeeded.
Running transaction
  Preparing        :                                                                                                                                                                                         1/1
  Installing       : python3.12-pip-wheel-23.2.1-5.el9.noarch                                                                                                                                               1/27
  Installing       : mpdecimal-2.5.1-3.el9.x86_64                                                                                                                                                           2/27
  Installing       : libnsl2-2.0.0-1.el9.0.1.x86_64                                                                                                                                                         3/27
  Installing       : python3.12-3.12.13-2.el9_8.x86_64                                                                                                                                                      4/27
  Installing       : python3.12-libs-3.12.13-2.el9_8.x86_64                                                                                                                                                 5/27
  Installing       : python3.12-dns-2.8.0-45PGDG.rhel9.6.noarch                                                                                                                                             6/27
  Installing       : python3.12-six-1.17.0-1PGDG.rhel9.noarch                                                                                                                                               7/27
  Installing       : python3.12-dateutil-2.9.0.post0-7PGDG.rhel9.6.noarch                                                                                                                                   8/27
  Installing       : py-consul-1.6.0-44PGDG.rhel9.noarch                                                                                                                                                    9/27
  Installing       : python3-ydiff-1.4.2-46PGDG.rhel9.noarch                                                                                                                                               10/27
  Installing       : python3.12-click-8.1.7-43PGDG.rhel9.noarch                                                                                                                                            11/27
  Installing       : python3.12-prettytable-3.4.0-43PGDG.rhel9.noarch                                                                                                                                      12/27
  Installing       : python3.12-psutil-6.1.1-42PGDG.rhel9.x86_64                                                                                                                                           13/27
  Installing       : python3.12-psycopg2-2.9.10-1PGDG.rhel9.x86_64                                                                                                                                         14/27
  Installing       : python3.12-systemd-235-42PGDG.rhel9.6.x86_64                                                                                                                                          15/27
  Installing       : python3.12-wcwidth-0.2.13-2PGDG.rhel9.noarch                                                                                                                                          16/27
  Installing       : python3.12-idna-3.4-2.el9.noarch                                                                                                                                                      17/27
  Installing       : python3.12-urllib3-1.26.19-3.el9_8.noarch                                                                                                                                             18/27
  Installing       : python3.12-etcd-0.4.5-48PGDG.rhel9.noarch                                                                                                                                             19/27
  Installing       : python3.12-ply-3.11-2.el9.noarch                                                                                                                                                      20/27
  Installing       : python3.12-pycparser-2.20-2.el9.noarch                                                                                                                                                21/27
  Installing       : python3.12-cffi-1.16.0-2.el9.x86_64                                                                                                                                                   22/27
  Installing       : python3.12-cryptography-41.0.7-3.el9.x86_64                                                                                                                                           23/27
  Installing       : python3.12-pyyaml-6.0.1-2.el9.x86_64                                                                                                                                                  24/27
  Installing       : patroni-4.1.5-1PGDG.rhel9.6.noarch                                                                                                                                                    25/27
  Running scriptlet: patroni-4.1.5-1PGDG.rhel9.6.noarch                                                                                                                                                    25/27
  Installing       : patroni-etcd-4.1.5-1PGDG.rhel9.6.noarch                                                                                                                                               26/27
  Running scriptlet: etcd-3.7.2-1PGDG.rhel9.6.x86_64                                                                                                                                                       27/27
Creating group 'etcd' with GID 989.
Creating user 'etcd' (etcd User) with UID 989 and GID 989.

  Installing       : etcd-3.7.2-1PGDG.rhel9.6.x86_64                                                                                                                                                       27/27
  Running scriptlet: etcd-3.7.2-1PGDG.rhel9.6.x86_64                                                                                                                                                       27/27
  Verifying        : patroni-4.1.5-1PGDG.rhel9.6.noarch                                                                                                                                                     1/27
  Verifying        : patroni-etcd-4.1.5-1PGDG.rhel9.6.noarch                                                                                                                                                2/27
  Verifying        : py-consul-1.6.0-44PGDG.rhel9.noarch                                                                                                                                                    3/27
  Verifying        : python3-ydiff-1.4.2-46PGDG.rhel9.noarch                                                                                                                                                4/27
  Verifying        : python3.12-click-8.1.7-43PGDG.rhel9.noarch                                                                                                                                             5/27
  Verifying        : python3.12-dateutil-2.9.0.post0-7PGDG.rhel9.6.noarch                                                                                                                                   6/27
  Verifying        : python3.12-dns-2.8.0-45PGDG.rhel9.6.noarch                                                                                                                                             7/27
  Verifying        : python3.12-etcd-0.4.5-48PGDG.rhel9.noarch                                                                                                                                              8/27
  Verifying        : python3.12-prettytable-3.4.0-43PGDG.rhel9.noarch                                                                                                                                       9/27
  Verifying        : python3.12-psutil-6.1.1-42PGDG.rhel9.x86_64                                                                                                                                           10/27
  Verifying        : python3.12-psycopg2-2.9.10-1PGDG.rhel9.x86_64                                                                                                                                         11/27
  Verifying        : python3.12-six-1.17.0-1PGDG.rhel9.noarch                                                                                                                                              12/27
  Verifying        : python3.12-systemd-235-42PGDG.rhel9.6.x86_64                                                                                                                                          13/27
  Verifying        : python3.12-wcwidth-0.2.13-2PGDG.rhel9.noarch                                                                                                                                          14/27
  Verifying        : etcd-3.7.2-1PGDG.rhel9.6.x86_64                                                                                                                                                       15/27
  Verifying        : libnsl2-2.0.0-1.el9.0.1.x86_64                                                                                                                                                        16/27
  Verifying        : mpdecimal-2.5.1-3.el9.x86_64                                                                                                                                                          17/27
  Verifying        : python3.12-3.12.13-2.el9_8.x86_64                                                                                                                                                     18/27
  Verifying        : python3.12-cffi-1.16.0-2.el9.x86_64                                                                                                                                                   19/27
  Verifying        : python3.12-cryptography-41.0.7-3.el9.x86_64                                                                                                                                           20/27
  Verifying        : python3.12-idna-3.4-2.el9.noarch                                                                                                                                                      21/27
  Verifying        : python3.12-libs-3.12.13-2.el9_8.x86_64                                                                                                                                                22/27
  Verifying        : python3.12-pip-wheel-23.2.1-5.el9.noarch                                                                                                                                              23/27
  Verifying        : python3.12-ply-3.11-2.el9.noarch                                                                                                                                                      24/27
  Verifying        : python3.12-pycparser-2.20-2.el9.noarch                                                                                                                                                25/27
  Verifying        : python3.12-pyyaml-6.0.1-2.el9.x86_64                                                                                                                                                  26/27
  Verifying        : python3.12-urllib3-1.26.19-3.el9_8.noarch                                                                                                                                             27/27

Installed:
  etcd-3.7.2-1PGDG.rhel9.6.x86_64                   libnsl2-2.0.0-1.el9.0.1.x86_64                 mpdecimal-2.5.1-3.el9.x86_64                         patroni-4.1.5-1PGDG.rhel9.6.noarch
  patroni-etcd-4.1.5-1PGDG.rhel9.6.noarch           py-consul-1.6.0-44PGDG.rhel9.noarch            python3-ydiff-1.4.2-46PGDG.rhel9.noarch              python3.12-3.12.13-2.el9_8.x86_64
  python3.12-cffi-1.16.0-2.el9.x86_64               python3.12-click-8.1.7-43PGDG.rhel9.noarch     python3.12-cryptography-41.0.7-3.el9.x86_64          python3.12-dateutil-2.9.0.post0-7PGDG.rhel9.6.noarch
  python3.12-dns-2.8.0-45PGDG.rhel9.6.noarch        python3.12-etcd-0.4.5-48PGDG.rhel9.noarch      python3.12-idna-3.4-2.el9.noarch                     python3.12-libs-3.12.13-2.el9_8.x86_64
  python3.12-pip-wheel-23.2.1-5.el9.noarch          python3.12-ply-3.11-2.el9.noarch               python3.12-prettytable-3.4.0-43PGDG.rhel9.noarch     python3.12-psutil-6.1.1-42PGDG.rhel9.x86_64
  python3.12-psycopg2-2.9.10-1PGDG.rhel9.x86_64     python3.12-pycparser-2.20-2.el9.noarch         python3.12-pyyaml-6.0.1-2.el9.x86_64                 python3.12-six-1.17.0-1PGDG.rhel9.noarch
  python3.12-systemd-235-42PGDG.rhel9.6.x86_64      python3.12-urllib3-1.26.19-3.el9_8.noarch      python3.12-wcwidth-0.2.13-2PGDG.rhel9.noarch

Complete!
[root@db3 ~]# etcd --version; patroni --version
etcd Version: 3.7.2
Git SHA: 68c065e
Go Version: go1.26.8
Go OS/Arch: linux/amd64
patroni 4.1.5

-- setting firewall on all nodes 
-- db1
[root@db1 ~]# firewall-cmd --permanent --add-port={2379,2380,8008}/tcp
success
[root@db1 ~]# sudo firewall-cmd --reload
success

-- db2 
[root@db2 ~]# firewall-cmd --permanent --add-port={2379,2380,8008}/tcp
success
[root@db2 ~]# firewall-cmd --reload
success

-- db3 
[root@db3 ~]# firewall-cmd --permanent --add-port={2379,2380,8008}/tcp
success
[root@db3 ~]# firewall-cmd --reload
success

-- A 2379 é o cliente do etcd, a 2380 é a comunicação entre os nós do etcd e a 8008 é a API do Patroni.

-- setting the ETCD on all nodes 
-- rules 
Parâmetro							Função												Valor
ETCD_NAME							Nome deste membro									local (db2, por exemplo)
ETCD_LISTEN_PEER_URLS				Onde este nó escuta os outros membros do etcd		ip local
ETCD_LISTEN_CLIENT_URLS				Onde este nó escuta os clientes (Patroni, etcdctl)	ip local + 127.0.0.1
ETCD_INITIAL_ADVERTISE_PEER_URLS	O endereço que este nó anuncia aos outros membros	ip local
ETCD_ADVERTISE_CLIENT_URLS	O endereço que este nó anuncia aos clientes					ip local
ETCD_INITIAL_CLUSTER	A lista de todos os membros										igual nos 3

-- db1 
sudo tee /etc/etcd/etcd.conf <<'EOF'
ETCD_NAME="db1"
ETCD_DATA_DIR="/var/lib/etcd"
ETCD_LISTEN_PEER_URLS="http://192.168.56.11:2380"
ETCD_LISTEN_CLIENT_URLS="http://192.168.56.11:2379,http://127.0.0.1:2379"
ETCD_INITIAL_ADVERTISE_PEER_URLS="http://192.168.56.11:2380"
ETCD_ADVERTISE_CLIENT_URLS="http://192.168.56.11:2379"
ETCD_INITIAL_CLUSTER="db1=http://192.168.56.11:2380,db2=http://192.168.56.12:2380,db3=http://192.168.56.13:2380"
ETCD_INITIAL_CLUSTER_STATE="new"
ETCD_INITIAL_CLUSTER_TOKEN="lab-etcd"
EOF 

-- db2
sudo tee /etc/etcd/etcd.conf <<'EOF' 
ETCD_NAME="db2"
ETCD_DATA_DIR="/var/lib/etcd"
ETCD_LISTEN_PEER_URLS="http://192.168.56.12:2380"
ETCD_LISTEN_CLIENT_URLS="http://192.168.56.12:2379,http://127.0.0.1:2379"
ETCD_INITIAL_ADVERTISE_PEER_URLS="http://192.168.56.12:2380"
ETCD_ADVERTISE_CLIENT_URLS="http://192.168.56.12:2379"
ETCD_INITIAL_CLUSTER="db1=http://192.168.56.11:2380,db2=http://192.168.56.12:2380,db3=http://192.168.56.13:2380"
ETCD_INITIAL_CLUSTER_STATE="new"
ETCD_INITIAL_CLUSTER_TOKEN="lab-etcd"
EOF 

-- db3
sudo tee /etc/etcd/etcd.conf <<'EOF' 
ETCD_NAME="db3"
ETCD_DATA_DIR="/var/lib/etcd"
ETCD_LISTEN_PEER_URLS="http://192.168.56.13:2380"
ETCD_LISTEN_CLIENT_URLS="http://192.168.56.13:2379,http://127.0.0.1:2379"
ETCD_INITIAL_ADVERTISE_PEER_URLS="http://192.168.56.13:2380"
ETCD_ADVERTISE_CLIENT_URLS="http://192.168.56.13:2379"
ETCD_INITIAL_CLUSTER="db1=http://192.168.56.11:2380,db2=http://192.168.56.12:2380,db3=http://192.168.56.13:2380"
ETCD_INITIAL_CLUSTER_STATE="new"
ETCD_INITIAL_CLUSTER_TOKEN="lab-etcd"
EOF 

-- starting ETCD on all nodes 
[root@db1 ~]# systemctl enable --now etcd
Created symlink /etc/systemd/system/multi-user.target.wants/etcd.service → /usr/lib/systemd/system/etcd.service.
[root@db2 ~]# systemctl enable --now etcd
Created symlink /etc/systemd/system/multi-user.target.wants/etcd.service → /usr/lib/systemd/system/etcd.service.
[root@db3 ~]# systemctl enable --now etcd
Created symlink /etc/systemd/system/multi-user.target.wants/etcd.service → /usr/lib/systemd/system/etcd.service.

--checking status (any node)
etcdctl --endpoints=192.168.56.11:2379,192.168.56.12:2379,192.168.56.13:2379 endpoint health
192.168.56.11:2379 is healthy: successfully committed proposal: took = 65.68857ms
192.168.56.12:2379 is healthy: successfully committed proposal: took = 132.247631ms
192.168.56.13:2379 is healthy: successfully committed proposal: took = 115.26992ms

[root@db1 ~]# etcdctl --endpoints=192.168.56.11:2379 member list -w table
┌──────────────────┬─────────┬──────┬───────────────────────────┬───────────────────────────┬────────────┐
│        ID        │ STATUS  │ NAME │        PEER ADDRS         │       CLIENT ADDRS        │ IS LEARNER │
├──────────────────┼─────────┼──────┼───────────────────────────┼───────────────────────────┼────────────┤
│ 1471ecde27028629 │ started │  db3 │ http://192.168.56.13:2380 │ http://192.168.56.13:2379 │      false │
│ 41e65971a6c68273 │ started │  db1 │ http://192.168.56.11:2380 │ http://192.168.56.11:2379 │      false │
│ c3fc039982b04fd7 │ started │  db2 │ http://192.168.56.12:2380 │ http://192.168.56.12:2379 │      false │
└──────────────────┴─────────┴──────┴───────────────────────────┴───────────────────────────┴────────────┘
-- OBS: ETCD is like the voting disks + ocr

-- Patroni Setup 
-- db1
sudo mkdir -p /etc/patroni
sudo tee /etc/patroni/patroni.yml <<'EOF'
scope: lab
name: db1

restapi:
  listen: 0.0.0.0:8008
  connect_address: 192.168.56.11:8008

etcd3:
  hosts: 192.168.56.11:2379,192.168.56.12:2379,192.168.56.13:2379

bootstrap:
  dcs:
    ttl: 30
    loop_wait: 10
    retry_timeout: 10
    maximum_lag_on_failover: 1048576
    postgresql:
      use_pg_rewind: true
      use_slots: true
      parameters:
        wal_level: replica
        hot_standby: "on"
        max_wal_senders: 10
        max_replication_slots: 10
        wal_log_hints: "on"
  initdb:
    - encoding: UTF8
    - data-checksums

postgresql:
  listen: 0.0.0.0:5432
  connect_address: 192.168.56.11:5432
  data_dir: /var/lib/pgsql/18/data
  bin_dir: /usr/pgsql-18/bin
  pgpass: /tmp/pgpass0
  authentication:
    superuser:
      username: postgres
      password: postgres
    replication:
      username: replicador
      password: repl123
    rewind:
      username: postgres
      password: postgres
  pg_hba:
    - local all all peer
    - host replication replicador 192.168.56.0/24 scram-sha-256
    - host all all 192.168.56.0/24 scram-sha-256
    - host all all 127.0.0.1/32 scram-sha-256
  parameters:
    unix_socket_directories: /run/postgresql

tags:
  nofailover: false
  noloadbalance: false
  clonefrom: false
  nosync: false
EOF
sudo chown -R postgres: /etc/patroni && sudo chmod 600 /etc/patroni/patroni.yml

-- db2 
sudo mkdir -p /etc/patroni
sudo tee /etc/patroni/patroni.yml <<'EOF'
scope: lab
name: db2

restapi:
  listen: 0.0.0.0:8008
  connect_address: 192.168.56.12:8008

etcd3:
  hosts: 192.168.56.11:2379,192.168.56.12:2379,192.168.56.13:2379

bootstrap:
  dcs:
    ttl: 30
    loop_wait: 10
    retry_timeout: 10
    maximum_lag_on_failover: 1048576
    postgresql:
      use_pg_rewind: true
      use_slots: true
      parameters:
        wal_level: replica
        hot_standby: "on"
        max_wal_senders: 10
        max_replication_slots: 10
        wal_log_hints: "on"
  initdb:
    - encoding: UTF8
    - data-checksums

postgresql:
  listen: 0.0.0.0:5432
  connect_address: 192.168.56.12:5432
  data_dir: /var/lib/pgsql/18/data
  bin_dir: /usr/pgsql-18/bin
  pgpass: /tmp/pgpass0
  authentication:
    superuser:
      username: postgres
      password: postgres
    replication:
      username: replicador
      password: repl123
    rewind:
      username: postgres
      password: postgres
  pg_hba:
    - local all all peer
    - host replication replicador 192.168.56.0/24 scram-sha-256
    - host all all 192.168.56.0/24 scram-sha-256
    - host all all 127.0.0.1/32 scram-sha-256
  parameters:
    unix_socket_directories: /run/postgresql

tags:
  nofailover: false
  noloadbalance: false
  clonefrom: false
  nosync: false
EOF
sudo chown -R postgres: /etc/patroni && sudo chmod 600 /etc/patroni/patroni.yml

-- db3 
sudo mkdir -p /etc/patroni
sudo tee /etc/patroni/patroni.yml <<'EOF'
scope: lab
name: db3

restapi:
  listen: 0.0.0.0:8008
  connect_address: 192.168.56.13:8008

etcd3:
  hosts: 192.168.56.11:2379,192.168.56.12:2379,192.168.56.13:2379

bootstrap:
  dcs:
    ttl: 30
    loop_wait: 10
    retry_timeout: 10
    maximum_lag_on_failover: 1048576
    postgresql:
      use_pg_rewind: true
      use_slots: true
      parameters:
        wal_level: replica
        hot_standby: "on"
        max_wal_senders: 10
        max_replication_slots: 10
        wal_log_hints: "on"
  initdb:
    - encoding: UTF8
    - data-checksums

postgresql:
  listen: 0.0.0.0:5432
  connect_address: 192.168.56.13:5432
  data_dir: /var/lib/pgsql/18/data
  bin_dir: /usr/pgsql-18/bin
  pgpass: /tmp/pgpass0
  authentication:
    superuser:
      username: postgres
      password: postgres
    replication:
      username: replicador
      password: repl123
    rewind:
      username: postgres
      password: postgres
  pg_hba:
    - local all all peer
    - host replication replicador 192.168.56.0/24 scram-sha-256
    - host all all 192.168.56.0/24 scram-sha-256
    - host all all 127.0.0.1/32 scram-sha-256
  parameters:
    unix_socket_directories: /run/postgresql

tags:
  nofailover: false
  noloadbalance: false
  clonefrom: false
  nosync: false
EOF
sudo chown -R postgres: /etc/patroni && sudo chmod 600 /etc/patroni/patroni.yml

-- starting patroni on 3 nodes 
-- db1
[root@db1 ~]# sudo systemctl enable --now patroni
Created symlink /etc/systemd/system/multi-user.target.wants/patroni.service → /usr/lib/systemd/system/patroni.service.

[root@db1 ~]# sudo journalctl -u patroni -f
Oct 17 15:58:49 db1 patroni[10687]: The default text search configuration will be set to "english".
Oct 17 15:58:49 db1 patroni[10687]: Data page checksums are enabled.
Oct 17 15:58:49 db1 patroni[10687]: creating directory /var/lib/pgsql/18/data ... ok
Oct 17 15:58:49 db1 patroni[10687]: creating subdirectories ... ok
Oct 17 15:58:49 db1 patroni[10687]: selecting dynamic shared memory implementation ... posix
Oct 17 15:58:49 db1 patroni[10687]: selecting default "max_connections" ... 100
Oct 17 15:58:50 db1 patroni[10687]: selecting default "shared_buffers" ... 128MB
Oct 17 15:58:50 db1 patroni[10687]: selecting default time zone ... Europe/Lisbon
Oct 17 15:58:50 db1 patroni[10687]: creating configuration files ... ok
Oct 17 15:58:51 db1 patroni[10687]: running bootstrap script ... ok
Oct 17 15:58:53 db1 patroni[10687]: performing post-bootstrap initialization ... ok
Oct 17 15:58:55 db1 patroni[10687]: syncing data to disk ... ok
Oct 17 15:58:56 db1 patroni[10687]: initdb: warning: enabling "trust" authentication for local connections
Oct 17 15:58:56 db1 patroni[10687]: initdb: hint: You can change this by editing pg_hba.conf or using the option -A, or --auth-local and --auth-host, the next time you run initdb.
Oct 17 15:58:56 db1 patroni[10687]: Success. You can now start the database server using:
Oct 17 15:58:56 db1 patroni[10687]:     /usr/pgsql-18/bin/pg_ctl -D /var/lib/pgsql/18/data -l logfile start
Oct 17 15:58:57 db1 patroni[10670]: 2026-10-17 15:58:57,318 INFO: postmaster pid=10705
Oct 17 15:58:57 db1 patroni[10705]: 2026-10-17 15:58:57.383 WEST [10705] LOG:  redirecting log output to logging collector process
Oct 17 15:58:57 db1 patroni[10705]: 2026-10-17 15:58:57.383 WEST [10705] HINT:  Future log output will appear in directory "log".
Oct 17 15:58:57 db1 patroni[10706]: localhost:5432 - accepting connections
Oct 17 15:58:57 db1 patroni[10720]: localhost:5432 - accepting connections
Oct 17 15:58:58 db1 patroni[10670]: 2026-10-17 15:58:58,004 INFO: establishing a new patroni heartbeat connection to postgres
Oct 17 15:58:58 db1 patroni[10670]: 2026-10-17 15:58:58,265 INFO: running post_bootstrap
Oct 17 15:58:58 db1 patroni[10670]: 2026-10-17 15:58:58,806 INFO: initialized a new cluster
Oct 17 15:58:58 db1 patroni[10670]: 2026-10-17 15:58:58,967 INFO: no action. I am (db1), the leader with the lock
Oct 17 15:59:09 db1 patroni[10670]: 2026-10-17 15:59:09,141 INFO: no action. I am (db1), the leader with the lock
Oct 17 15:59:19 db1 patroni[10670]: 2026-10-17 15:59:19,160 INFO: no action. I am (db1), the leader with the lock

-- db2
[root@db2 ~]# sudo systemctl enable --now patroni
Created symlink /etc/systemd/system/multi-user.target.wants/patroni.service → /usr/lib/systemd/system/patroni.service.

[root@db2 ~]# sudo journalctl -u patroni -f
Oct 17 15:59:00 db2 systemd[1]: Starting Runners to orchestrate a high-availability PostgreSQL...
Oct 17 15:59:01 db2 patroni[21189]: 2026-10-17 15:59:01,876 INFO: Using default value thread_stack_size = 524288
Oct 17 15:59:01 db2 patroni[21189]: 2026-10-17 15:59:01,935 INFO: Patroni global thread_pool_size = 5
Oct 17 15:59:02 db2 patroni[21189]: 2026-10-17 15:59:02,170 INFO: Selected new etcd server http://192.168.56.11:2379
Oct 17 15:59:02 db2 patroni[21189]: 2026-10-17 15:59:02,250 INFO: No PostgreSQL configuration items changed, nothing to reload.
Oct 17 15:59:02 db2 patroni[21189]: 2026-10-17 15:59:02,262 INFO: REST API thread_pool_size = 5
Oct 17 15:59:02 db2 systemd[1]: Started Runners to orchestrate a high-availability PostgreSQL.
Oct 17 15:59:02 db2 patroni[21189]: 2026-10-17 15:59:02,378 INFO: Lock owner: db1; I am db2
Oct 17 15:59:02 db2 patroni[21189]: 2026-10-17 15:59:02,459 INFO: trying to bootstrap from leader 'db1'
Oct 17 15:59:08 db2 patroni[21189]: 2026-10-17 15:59:08,083 INFO: replica has been created using basebackup
Oct 17 15:59:08 db2 patroni[21189]: 2026-10-17 15:59:08,084 INFO: bootstrapped from leader 'db1'
Oct 17 15:59:09 db2 patroni[21189]: 2026-10-17 15:59:08,934 INFO: Lock owner: db1; I am db2
Oct 17 15:59:09 db2 patroni[21189]: 2026-10-17 15:59:09,094 INFO: bootstrap from leader 'db1' in progress
Oct 17 15:59:09 db2 patroni[21189]: 2026-10-17 15:59:09,390 INFO: postmaster pid=21218
Oct 17 15:59:09 db2 patroni[21219]: localhost:5432 - no response
Oct 17 15:59:09 db2 patroni[21218]: 2026-10-17 15:59:09.505 WEST [21218] LOG:  redirecting log output to logging collector process
Oct 17 15:59:09 db2 patroni[21218]: 2026-10-17 15:59:09.505 WEST [21218] HINT:  Future log output will appear in directory "log".
Oct 17 15:59:10 db2 patroni[21227]: localhost:5432 - rejecting connections
Oct 17 15:59:10 db2 patroni[21229]: localhost:5432 - rejecting connections
Oct 17 15:59:11 db2 patroni[21231]: localhost:5432 - rejecting connections
Oct 17 15:59:12 db2 patroni[21234]: localhost:5432 - accepting connections
Oct 17 15:59:12 db2 patroni[21189]: 2026-10-17 15:59:12,923 INFO: Lock owner: db1; I am db2
Oct 17 15:59:12 db2 patroni[21189]: 2026-10-17 15:59:12,923 INFO: establishing a new patroni heartbeat connection to postgres
Oct 17 15:59:13 db2 patroni[21189]: 2026-10-17 15:59:13,257 INFO: no action. I am (db2), a secondary, and following a leader (db1)
Oct 17 15:59:19 db2 patroni[21189]: 2026-10-17 15:59:19,475 INFO: no action. I am (db2), a secondary, and following a leader (db1)
Oct 17 15:59:29 db2 patroni[21189]: 2026-10-17 15:59:29,103 INFO: no action. I am (db2), a secondary, and following a leader (db1)

-- db3 
[root@db3 ~]# sudo systemctl enable --now patroni
Created symlink /etc/systemd/system/multi-user.target.wants/patroni.service → /usr/lib/systemd/system/patroni.service.

[root@db3 ~]# sudo journalctl -u patroni -f
Oct 17 15:59:15 db3 systemd[1]: Starting Runners to orchestrate a high-availability PostgreSQL...
Oct 17 15:59:16 db3 patroni[7050]: 2026-10-17 15:59:16,362 INFO: Using default value thread_stack_size = 524288
Oct 17 15:59:16 db3 patroni[7050]: 2026-10-17 15:59:16,379 INFO: Patroni global thread_pool_size = 5
Oct 17 15:59:16 db3 patroni[7050]: 2026-10-17 15:59:16,636 INFO: Selected new etcd server http://192.168.56.11:2379
Oct 17 15:59:16 db3 patroni[7050]: 2026-10-17 15:59:16,724 INFO: No PostgreSQL configuration items changed, nothing to reload.
Oct 17 15:59:16 db3 patroni[7050]: 2026-10-17 15:59:16,734 INFO: REST API thread_pool_size = 5
Oct 17 15:59:16 db3 systemd[1]: Started Runners to orchestrate a high-availability PostgreSQL.
Oct 17 15:59:16 db3 patroni[7050]: 2026-10-17 15:59:16,866 INFO: Lock owner: db1; I am db3
Oct 17 15:59:16 db3 patroni[7050]: 2026-10-17 15:59:16,960 INFO: trying to bootstrap from leader 'db1'
Oct 17 15:59:19 db3 patroni[7050]: 2026-10-17 15:59:19,008 INFO: Lock owner: db1; I am db3
Oct 17 15:59:19 db3 patroni[7050]: 2026-10-17 15:59:19,270 INFO: bootstrap from leader 'db1' in progress
Oct 17 15:59:23 db3 patroni[7050]: 2026-10-17 15:59:23,456 INFO: replica has been created using basebackup
Oct 17 15:59:23 db3 patroni[7050]: 2026-10-17 15:59:23,457 INFO: bootstrapped from leader 'db1'
Oct 17 15:59:24 db3 patroni[7050]: 2026-10-17 15:59:24,967 INFO: postmaster pid=7080
Oct 17 15:59:25 db3 patroni[7081]: localhost:5432 - no response
Oct 17 15:59:25 db3 patroni[7080]: 2026-10-17 15:59:25.062 WEST [7080] LOG:  redirecting log output to logging collector process
Oct 17 15:59:25 db3 patroni[7080]: 2026-10-17 15:59:25.062 WEST [7080] HINT:  Future log output will appear in directory "log".
Oct 17 15:59:26 db3 patroni[7089]: localhost:5432 - rejecting connections
Oct 17 15:59:26 db3 patroni[7091]: localhost:5432 - rejecting connections
Oct 17 15:59:27 db3 patroni[7093]: localhost:5432 - rejecting connections
Oct 17 15:59:28 db3 patroni[7096]: localhost:5432 - accepting connections
Oct 17 15:59:28 db3 patroni[7050]: 2026-10-17 15:59:28,391 INFO: Lock owner: db1; I am db3
Oct 17 15:59:28 db3 patroni[7050]: 2026-10-17 15:59:28,391 INFO: establishing a new patroni heartbeat connection to postgres
Oct 17 15:59:28 db3 patroni[7050]: 2026-10-17 15:59:28,856 INFO: no action. I am (db3), a secondary, and following a leader (db1)
Oct 17 15:59:29 db3 patroni[7050]: 2026-10-17 15:59:29,054 INFO: no action. I am (db3), a secondary, and following a leader (db1)
Oct 17 15:59:39 db3 patroni[7050]: 2026-10-17 15:59:39,522 INFO: no action. I am (db3), a secondary, and following a leader (db1)

-- checking status 
[root@db1 ~]# patronictl -c /etc/patroni/patroni.yml list
+ Cluster: lab (7697651400992291269) ----------+----+-------------+-----+------------+-----+
| Member |      Host     |   Role  |   State   | TL | Receive LSN | Lag | Replay LSN | Lag |
+--------+---------------+---------+-----------+----+-------------+-----+------------+-----+
| db1    | 192.168.56.11 | Leader  | running   |  1 |             |     |            |     |
| db2    | 192.168.56.12 | Replica | streaming |  1 |   0/5041188 |   0 |  0/5041188 |   0 |
| db3    | 192.168.56.13 | Replica | streaming |  1 |   0/5041188 |   0 |  0/5041188 |   0 |
+--------+---------------+---------+-----------+----+-------------+-----+------------+-----+

-- checking the parameters made by patroni 
-- db1 
[postgres@db1 ~]$ psql -c "SELECT slot_name, active FROM pg_replication_slots;"
 slot_name | active
-----------+--------
 db2       | t
 db3       | t
(2 rows)

[postgres@db1 ~]$ psql -c "SELECT application_name, state FROM pg_stat_replication;"
 application_name |   state
------------------+-----------
 db2              | streaming
 db3              | streaming
(2 rows)

-- db2 
[postgres@db2 ~]$ grep -E "primary_conninfo|primary_slot_name" /var/lib/pgsql/18/data/postgresql.conf
primary_conninfo = 'dbname=postgres user=replicador passfile=/tmp/pgpass0 host=192.168.56.11 port=5432 sslmode=prefer application_name=db2 gssencmode=prefer channel_binding=prefer sslnegotiation=postgres'
primary_slot_name = 'db2'

-- db3 
[root@db3 ~]# grep -E "primary_conninfo|primary_slot_name" /var/lib/pgsql/18/data/postgresql.conf
primary_conninfo = 'dbname=postgres user=replicador passfile=/tmp/pgpass0 host=192.168.56.11 port=5432 sslmode=prefer application_name=db3 gssencmode=prefer channel_binding=prefer sslnegotiation=postgres'
primary_slot_name = 'db3'

-- performing switchover 
patronictl -c /etc/patroni/patroni.yml switchover
Current cluster topology
+ Cluster: lab (7697651400992291269) ----------+----+-------------+-----+------------+-----+
| Member |      Host     |   Role  |   State   | TL | Receive LSN | Lag | Replay LSN | Lag |
+--------+---------------+---------+-----------+----+-------------+-----+------------+-----+
| db1    | 192.168.56.11 | Leader  | running   |  1 |             |     |            |     |
| db2    | 192.168.56.12 | Replica | streaming |  1 |   0/5041290 |   0 |  0/5041290 |   0 |
| db3    | 192.168.56.13 | Replica | streaming |  1 |   0/5041290 |   0 |  0/5041290 |   0 |
+--------+---------------+---------+-----------+----+-------------+-----+------------+-----+
Primary [db1]:
Candidate ['db2', 'db3'] []: db2
When should the switchover take place (e.g. 2026-10-17T17:06 )  [now]:
Are you sure you want to switchover cluster lab, demoting current leader db1? [y/N]: y
2026-10-17 16:06:55.63534 Successfully switched over to "db2"
+ Cluster: lab (7697651400992291269) --------+----+-------------+-----+------------+-----+
| Member |      Host     |   Role  |  State  | TL | Receive LSN | Lag | Replay LSN | Lag |
+--------+---------------+---------+---------+----+-------------+-----+------------+-----+
| db1    | 192.168.56.11 | Replica | stopped |    |     unknown |     |    unknown |     |
| db2    | 192.168.56.12 | Leader  | running |    |             |     |            |     |
| db3    | 192.168.56.13 | Replica | running |    |   0/50413D8 |   0 |  0/50413D8 |   0 |
+--------+---------------+---------+---------+----+-------------+-----+------------+-----+

patronictl -c /etc/patroni/patroni.yml list
+ Cluster: lab (7697651400992291269) ----------+----+-------------+-----+------------+-----+
| Member |      Host     |   Role  |   State   | TL | Receive LSN | Lag | Replay LSN | Lag |
+--------+---------------+---------+-----------+----+-------------+-----+------------+-----+
| db1    | 192.168.56.11 | Replica | streaming |  2 |   0/5041518 |   0 |  0/5041518 |   0 |
| db2    | 192.168.56.12 | Leader  | running   |  2 |             |     |            |     |
| db3    | 192.168.56.13 | Replica | streaming |  2 |   0/5041518 |   0 |  0/5041518 |   0 |
+--------+---------------+---------+-----------+----+-------------+-----+------------+-----+

-- forcing failover
-- shutdown the db1 (leader) 
vagrant halt db1 --force

-- checking the list after 30 seconds
[postgres@db2 ~]$ patronictl -c /etc/patroni/patroni.yml list
+ Cluster: lab (7697651400992291269) ----------+----+-------------+-----+------------+-----+
| Member |      Host     |   Role  |   State   | TL | Receive LSN | Lag | Replay LSN | Lag |
+--------+---------------+---------+-----------+----+-------------+-----+------------+-----+
| db2    | 192.168.56.12 | Leader  | running   |  4 |             |     |            |     |
| db3    | 192.168.56.13 | Replica | streaming |  4 |   0/50418A8 |   0 |  0/50418A8 |   0 |
+--------+---------------+---------+-----------+----+-------------+-----+------------+-----+

-- starting db1 and check list again
vagrant up db1 

-- db2 
[postgres@db2 ~]$ patronictl -c /etc/patroni/patroni.yml list
+ Cluster: lab (7697651400992291269) ----------+----+-------------+-----+------------+-----+
| Member |      Host     |   Role  |   State   | TL | Receive LSN | Lag | Replay LSN | Lag |
+--------+---------------+---------+-----------+----+-------------+-----+------------+-----+
| db1    | 192.168.56.11 | Replica | streaming |  4 |   0/50418E0 |   0 |  0/50418E0 |   0 |
| db2    | 192.168.56.12 | Leader  | running   |  4 |             |     |            |     |
| db3    | 192.168.56.13 | Replica | streaming |  4 |   0/50418E0 |   0 |  0/50418E0 |   0 |
+--------+---------------+---------+-----------+----+-------------+-----+------------+-----+

-- changing one replica to sync mode = true 
-- db3 
[root@db3 ~]# patronictl -c /etc/patroni/patroni.yml edit-config
---
+++
@@ -11,3 +11,4 @@
   use_slots: true
 retry_timeout: 10
 ttl: 30
+synchronous_mode: true

Apply these changes? [y/N]: y
Configuration changed

-- checking the list (db3 show like Sync Standby) 
[postgres@db2 ~]$ patronictl -c /etc/patroni/patroni.yml list
+ Cluster: lab (7697651400992291269) ---+-----------+----+-------------+-----+------------+-----+
| Member |      Host     |     Role     |   State   | TL | Receive LSN | Lag | Replay LSN | Lag |
+--------+---------------+--------------+-----------+----+-------------+-----+------------+-----+
| db1    | 192.168.56.11 | Replica      | streaming |  4 |   0/50418E0 |   0 |  0/50418E0 |   0 |
| db2    | 192.168.56.12 | Leader       | running   |  4 |             |     |            |     |
| db3    | 192.168.56.13 | Sync Standby | streaming |  4 |   0/50418E0 |   0 |  0/50418E0 |   0 |
+--------+---------------+--------------+-----------+----+-------------+-----+------------+-----+

-- stop patroni on db3
sudo systemctl stop patroni

-- check the list (the other replica was changed to Sync Standby)
[postgres@db2 ~]$ patronictl -c /etc/patroni/patroni.yml list
+ Cluster: lab (7697651400992291269) ---+-----------+----+-------------+-----+------------+-----+
| Member |      Host     |     Role     |   State   | TL | Receive LSN | Lag | Replay LSN | Lag |
+--------+---------------+--------------+-----------+----+-------------+-----+------------+-----+
| db1    | 192.168.56.11 | Sync Standby | streaming |  4 |   0/5041A70 |   0 |  0/5041A70 |   0 |
| db2    | 192.168.56.12 | Leader       | running   |  4 |             |     |            |     |
| db3    | 192.168.56.13 | Replica      | stopped   |    |     unknown |     |    unknown |     |
+--------+---------------+--------------+-----------+----+-------------+-----+------------+-----+

-- restarting node 3 and checking list 
[root@db3 ~]# sudo systemctl start patroni

[postgres@db2 ~]$ patronictl -c /etc/patroni/patroni.yml list
+ Cluster: lab (7697651400992291269) ---+-----------+----+-------------+-----+------------+-----+
| Member |      Host     |     Role     |   State   | TL | Receive LSN | Lag | Replay LSN | Lag |
+--------+---------------+--------------+-----------+----+-------------+-----+------------+-----+
| db1    | 192.168.56.11 | Sync Standby | streaming |  4 |   0/5041AA8 |   0 |  0/5041AA8 |   0 |
| db2    | 192.168.56.12 | Leader       | running   |  4 |             |     |            |     |
| db3    | 192.168.56.13 | Replica      | streaming |  4 |   0/5041AA8 |   0 |  0/5041AA8 |   0 |
+--------+---------------+--------------+-----------+----+-------------+-----+------------+-----+

-- MAINTANENCE MODE - Usefull to avoid automatic failover 
-- db2 (leader) 
[postgres@db2 ~]$ patronictl -c /etc/patroni/patroni.yml pause
Success: cluster management is paused
[root@db1 ~]# patronictl -c /etc/patroni/patroni.yml list
+ Cluster: lab (7697651400992291269) ---+-----------+----+-------------+-----+------------+-----+
| Member |      Host     |     Role     |   State   | TL | Receive LSN | Lag | Replay LSN | Lag |
+--------+---------------+--------------+-----------+----+-------------+-----+------------+-----+
| db1    | 192.168.56.11 | Sync Standby | streaming |  4 |   0/5041BB0 |   0 |  0/5041BB0 |   0 |
| db2    | 192.168.56.12 | Leader       | running   |  4 |             |     |            |     |
| db3    | 192.168.56.13 | Replica      | streaming |  4 |   0/5041BB0 |   0 |  0/5041BB0 |   0 |
+--------+---------------+--------------+-----------+----+-------------+-----+------------+-----+
 Maintenance mode: on <== CHECK THIS OUT!!!
 
-- performing resume and checking again 
[postgres@db2 ~]$ patronictl -c /etc/patroni/patroni.yml resume
Success: cluster management is resumed

[root@db1 ~]# patronictl -c /etc/patroni/patroni.yml list
+ Cluster: lab (7697651400992291269) ---+-----------+----+-------------+-----+------------+-----+
| Member |      Host     |     Role     |   State   | TL | Receive LSN | Lag | Replay LSN | Lag |
+--------+---------------+--------------+-----------+----+-------------+-----+------------+-----+
| db1    | 192.168.56.11 | Sync Standby | streaming |  4 |   0/5041BB0 |   0 |  0/5041BB0 |   0 |
| db2    | 192.168.56.12 | Leader       | running   |  4 |             |     |            |     |
| db3    | 192.168.56.13 | Replica      | streaming |  4 |   0/5041BB0 |   0 |  0/5041BB0 |   0 |
+--------+---------------+--------------+-----------+----+-------------+-----+------------+-----+


-- seeting API REST - router
for n in 11 12 13; do echo -n "192.168.56.$n /primary: "; curl -s -o /dev/null -w "%{http_code}\n" http://192.168.56.$n:8008/primary; done
-- Só o líder responde 200; os outros, 503. É isso que um HAProxy usa para mandar as conexões de escrita ao nó certo.


