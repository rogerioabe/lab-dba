-- new backup
[vagrant@db1 ~]$ sudo -iu postgres pg_basebackup -D /backup/base_02 -Ft -z -P -X stream -c fast
924031/924031 kB (100%), 2/2 tablespaces

--input new data
[vagrant@db1 ~]$ sudo -iu postgres psql -d lab <<'EOF'
CREATE TABLE importante AS SELECT g AS id, 'dado ' || g AS v FROM generate_series(1,1000) g;
SELECT pg_create_restore_point('antes_do_desastre');
SELECT now();
EOF
SELECT 1000
 pg_create_restore_point
-------------------------
 0/EB02FF98
(1 row)

              now
-------------------------------
 2026-10-14 18:44:16.436574+01
(1 row)

-- the disaster
[vagrant@db1 ~]$ sleep 5
sudo -iu postgres psql -d lab -c "DROP TABLE importante;"
sudo -iu postgres psql -c "SELECT pg_switch_wal();"
DROP TABLE
 pg_switch_wal
---------------
 0/EB030BC8
(1 row)

-- restoring using PTTR
[vagrant@db1 ~]$ sudo systemctl stop postgresql-18
sudo mv /var/lib/pgsql/18/data /var/lib/pgsql/18/data_pre_pitr
sudo -iu postgres mkdir -m 700 /var/lib/pgsql/18/data
sudo -iu postgres tar -xzf /backup/base_02/base.tar.gz -C /var/lib/pgsql/18/data
sudo -iu postgres tar -xzf /backup/base_02/pg_wal.tar.gz -C /var/lib/pgsql/18/data/pg_wal
sudo rm -rf /pgdata/ts_rapida/*
*/
sudo -iu postgres tar -xzf /backup/base_02/16433.tar.gz -C /pgdata/ts_rapida

[vagrant@db1 ~]$ sudo -iu postgres tee -a /var/lib/pgsql/18/data/postgresql.auto.conf <<'EOF'
restore_command = 'cp /pgarchive/%f %p'
recovery_target_name = 'antes_do_desastre'
recovery_target_action = 'pause'
EOF
restore_command = 'cp /pgarchive/%f %p'
recovery_target_name = 'antes_do_desastre'
recovery_target_action = 'pause'

[vagrant@db1 ~]$ sudo -iu postgres touch /var/lib/pgsql/18/data/recovery.signal
[vagrant@db1 ~]$ sudo systemctl start postgresql-18

[vagrant@db1 ~]$ sudo -iu postgres psql -d lab -c "SELECT count(*) FROM importante;"
 count
-------
  1000
  
[vagrant@db1 ~]$ sudo -iu postgres psql -c "SELECT pg_is_in_recovery(), pg_get_wal_replay_pause_state(), pg_last_xact_replay_timestamp();"
 pg_is_in_recovery | pg_get_wal_replay_pause_state | pg_last_xact_replay_timestamp
-------------------+-------------------------------+-------------------------------
 t                 | paused                        | 2026-10-14 18:44:16.403323+01
(1 row)

[vagrant@db1 ~]$ sudo -iu postgres psql -d lab -c "INSERT INTO importante VALUES (0,'x');"
ERROR:  cannot execute INSERT in a read-only transaction  <=== falhou pq está em mode pause

-- checking the timeline
[vagrant@db1 ~]$ sudo -iu postgres /usr/pgsql-18/bin/pg_controldata /var/lib/pgsql/18/data | grep -i timeline
Latest checkpoint's TimeLineID:       3
Latest checkpoint's PrevTimeLineID:   2
Min recovery ending loc's timeline:   0
'
[vagrant@db1 ~]$ ls /pgarchive/*.history
/pgarchive/00000002.history  /pgarchive/00000003.history

*/
-- cleaning the target parameters 
[vagrant@db1 ~]$ sudo -iu postgres sed -i '/^recovery_target/d' /var/lib/pgsql/18/data/postgresql.auto.conf


### Bloco 2: pgBackRest
-- installing and configurating 
[vagrant@db1 ~]$ sudo dnf install -y epel-release
Last metadata expiration check: 2:24:11 ago on Wed 14 Oct 2026 04:33:45 PM WEST.
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
epel-release-9-10.el9.noarch.rpm                                                                                                                                                 319 kB/s |  19 kB     00:00
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Total                                                                                                                                                                             62 kB/s |  19 kB     00:00
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
[vagrant@db1 ~]$ sudo dnf install -y pgbackrest
Extra Packages for Enterprise Linux 9 - x86_64                                                                                                                                    10 MB/s |  20 MB     00:01
Extra Packages for Enterprise Linux 9 openh264 (From Cisco) - x86_64                                                                                                             3.3 kB/s | 2.5 kB     00:00
Dependencies resolved.
=================================================================================================================================================================================================================
 Package                                         Architecture                                Version                                                      Repository                                        Size
=================================================================================================================================================================================================================
Installing:
 pgbackrest                                      x86_64                                      2.59.3-1PGDG.rhel9.6                                         pgdg-common                                      558 k
Installing dependencies:
 libssh2                                         x86_64                                      1.11.1-9.el9                                                 epel                                             141 k

Transaction Summary
=================================================================================================================================================================================================================
Install  2 Packages

Total download size: 699 k
Installed size: 1.6 M
Downloading Packages:
(1/2): pgbackrest-2.59.3-1PGDG.rhel9.6.x86_64.rpm                                                                                                                                2.5 MB/s | 558 kB     00:00
(2/2): libssh2-1.11.1-9.el9.x86_64.rpm                                                                                                                                           366 kB/s | 141 kB     00:00
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Total                                                                                                                                                                            1.1 MB/s | 699 kB     00:00
Extra Packages for Enterprise Linux 9 - x86_64                                                                                                                                   613 kB/s | 1.6 kB     00:00
Importing GPG key 0x3228467C:
 Userid     : "Fedora (epel9) <epel@fedoraproject.org>"
 Fingerprint: FF8A D134 4597 106E CE81 3B91 8A38 72BF 3228 467C
 From       : /etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-9
Key imported successfully
Running transaction check
Transaction check succeeded.
Running transaction test
Transaction test succeeded.
Running transaction
  Preparing        :                                                                                                                                                                                         1/1
  Installing       : libssh2-1.11.1-9.el9.x86_64                                                                                                                                                             1/2
  Running scriptlet: pgbackrest-2.59.3-1PGDG.rhel9.6.x86_64                                                                                                                                                  2/2
  Installing       : pgbackrest-2.59.3-1PGDG.rhel9.6.x86_64                                                                                                                                                  2/2
warning: /etc/pgbackrest.conf created as /etc/pgbackrest.conf.rpmnew

  Running scriptlet: pgbackrest-2.59.3-1PGDG.rhel9.6.x86_64                                                                                                                                                  2/2
  Verifying        : libssh2-1.11.1-9.el9.x86_64                                                                                                                                                             1/2
  Verifying        : pgbackrest-2.59.3-1PGDG.rhel9.6.x86_64                                                                                                                                                  2/2

Installed:
  libssh2-1.11.1-9.el9.x86_64                                                                       pgbackrest-2.59.3-1PGDG.rhel9.6.x86_64

Complete!

[vagrant@db1 ~]$ pgbackrest version
pgBackRest 2.59.3

[vagrant@db1 ~]$ sudo mkdir -p /var/lib/pgbackrest /var/log/pgbackrest
[vagrant@db1 ~]$ sudo chown postgres: /var/lib/pgbackrest /var/log/pgbackrest
[vagrant@db1 ~]$ sudo tee /etc/pgbackrest.conf <<'EOF'
[global]
repo1-path=/var/lib/pgbackrest
repo1-retention-full=2
start-fast=y
compress-type=zst
process-max=2
log-level-console=info

[lab]
pg1-path=/var/lib/pgsql/18/data
EOF
[global]
repo1-path=/var/lib/pgbackrest
repo1-retention-full=2
start-fast=y
compress-type=zst
process-max=2
log-level-console=info

[lab]
pg1-path=/var/lib/pgsql/18/data

-- changing the archiving mode 
[vagrant@db1 ~]$ sudo -iu postgres psql -c "ALTER SYSTEM SET archive_command = 'pgbackrest --stanza=lab archive-push %p';"
ALTER SYSTEM
[vagrant@db1 ~]$ sudo -iu postgres psql -c "SELECT pg_reload_conf();"
 pg_reload_conf
----------------
 t
(1 row)


-- creating the stanza (register catalog) 
[vagrant@db1 ~]$ sudo -iu postgres pgbackrest --stanza=lab stanza-create
2026-10-14 19:00:53.477 P00   INFO: stanza-create command begin 2.59.3: --exec-id=7275-3cb239dd --log-level-console=info --pg1-path=/var/lib/pgsql/18/data --repo1-path=/var/lib/pgbackrest --stanza=lab
2026-10-14 19:00:53.677 P00   INFO: stanza-create for stanza 'lab' on repo1
2026-10-14 19:00:53.758 P00   INFO: stanza-create command end: completed successfully (296ms)
[vagrant@db1 ~]$ sudo -iu postgres pgbackrest --stanza=lab check
2026-10-14 19:01:35.834 P00   INFO: check command begin 2.59.3: --exec-id=7336-9a9b930b --log-level-console=info --pg1-path=/var/lib/pgsql/18/data --repo1-path=/var/lib/pgbackrest --stanza=lab
2026-10-14 19:01:35.883 P00   INFO: check repo1 configuration (primary)
2026-10-14 19:01:36.041 P00   INFO: check repo1 archive for WAL (primary)
2026-10-14 19:01:36.361 P00   INFO: WAL segment 0000000300000000000000EB successfully archived to '/var/lib/pgbackrest/archive/lab/18-1/0000000300000000/0000000300000000000000EB-3c21e941c975558be91c4a5f7be3e215fe9d609c.zst' on repo1
2026-10-14 19:01:36.362 P00   INFO: check command end: completed successfully (539ms)

-- performing full, diff and inc backups 
-- FULL
[vagrant@db1 ~]$ sudo -iu postgres pgbackrest --stanza=lab --type=full backup
2026-10-14 19:02:33.761 P00   INFO: backup command begin 2.59.3: --compress-type=zst --exec-id=7387-c674bc8c --log-level-console=info --pg1-path=/var/lib/pgsql/18/data --process-max=2 --repo1-path=/var/lib/pgbackrest --repo1-retention-full=2 --stanza=lab --start-fast --type=full
2026-10-14 19:02:33.871 P00   INFO: execute backup start: backup begins after the requested immediate checkpoint completes
2026-10-14 19:02:34.177 P00   INFO: backup start archive = 0000000300000000000000ED, lsn = 0/ED000028
2026-10-14 19:02:34.177 P00   INFO: check archive for prior segment 0000000300000000000000EC
2026-10-14 19:03:12.924 P00   INFO: execute backup stop and wait for all WAL segments to archive
2026-10-14 19:03:13.078 P00   INFO: backup stop archive = 0000000300000000000000ED, lsn = 0/ED000158
2026-10-14 19:03:13.125 P00   INFO: check archive for segment(s) 0000000300000000000000ED:0000000300000000000000ED
2026-10-14 19:03:13.285 P00   INFO: new backup label = 20261014-190233F
2026-10-14 19:03:13.614 P00   INFO: full backup size = 901.4MB, file total = 2222
2026-10-14 19:03:13.619 P00   INFO: backup command end: completed successfully (39874ms)
2026-10-14 19:03:13.620 P00   INFO: expire command begin 2.59.3: --exec-id=7387-c674bc8c --log-level-console=info --repo1-path=/var/lib/pgbackrest --repo1-retention-full=2 --stanza=lab
2026-10-14 19:03:13.625 P00   INFO: expire command end: completed successfully (6ms)

[vagrant@db1 ~]$ sudo -iu postgres psql -d lab -c "CREATE TABLE apos_full AS SELECT now() AS t;"
SELECT 1

-- DIFF 
[vagrant@db1 ~]$ sudo -iu postgres pgbackrest --stanza=lab --type=diff backup
2026-10-14 19:03:44.330 P00   INFO: backup command begin 2.59.3: --compress-type=zst --exec-id=7486-8710f7c0 --log-level-console=info --pg1-path=/var/lib/pgsql/18/data --process-max=2 --repo1-path=/var/lib/pgbackrest --repo1-retention-full=2 --stanza=lab --start-fast --type=diff
2026-10-14 19:03:44.421 P00   INFO: last backup label = 20261014-190233F, version = 2.59.3
2026-10-14 19:03:44.422 P00   INFO: execute backup start: backup begins after the requested immediate checkpoint completes
2026-10-14 19:03:44.720 P00   INFO: backup start archive = 0000000300000000000000EF, lsn = 0/EF000028
2026-10-14 19:03:44.720 P00   INFO: check archive for prior segment 0000000300000000000000EE
2026-10-14 19:03:45.632 P00   INFO: execute backup stop and wait for all WAL segments to archive
2026-10-14 19:03:45.711 P00   INFO: backup stop archive = 0000000300000000000000EF, lsn = 0/EF000120
2026-10-14 19:03:45.756 P00   INFO: check archive for segment(s) 0000000300000000000000EF:0000000300000000000000EF
2026-10-14 19:03:45.932 P00   INFO: new backup label = 20261014-190233F_20261014-190344D
2026-10-14 19:03:46.240 P00   INFO: diff backup size = 1.4MB, file total = 2223
2026-10-14 19:03:46.240 P00   INFO: backup command end: completed successfully (1916ms)
2026-10-14 19:03:46.240 P00   INFO: expire command begin 2.59.3: --exec-id=7486-8710f7c0 --log-level-console=info --repo1-path=/var/lib/pgbackrest --repo1-retention-full=2 --stanza=lab
2026-10-14 19:03:46.248 P00   INFO: expire command end: completed successfully (8ms)

[vagrant@db1 ~]$ sudo -iu postgres psql -d lab -c "INSERT INTO apos_full SELECT now();"
INSERT 0 1

-- INC 
[vagrant@db1 ~]$ sudo -iu postgres pgbackrest --stanza=lab --type=incr backup
2026-10-14 19:04:41.510 P00   INFO: backup command begin 2.59.3: --compress-type=zst --exec-id=7584-6e3c22e0 --log-level-console=info --pg1-path=/var/lib/pgsql/18/data --process-max=2 --repo1-path=/var/lib/pgbackrest --repo1-retention-full=2 --stanza=lab --start-fast --type=incr
2026-10-14 19:04:41.628 P00   INFO: last backup label = 20261014-190233F_20261014-190344D, version = 2.59.3
2026-10-14 19:04:41.629 P00   INFO: execute backup start: backup begins after the requested immediate checkpoint completes
2026-10-14 19:04:41.867 P00   INFO: backup start archive = 0000000300000000000000F1, lsn = 0/F1000028
2026-10-14 19:04:41.868 P00   INFO: check archive for prior segment 0000000300000000000000F0
2026-10-14 19:04:42.469 P00   INFO: execute backup stop and wait for all WAL segments to archive
2026-10-14 19:04:42.509 P00   INFO: backup stop archive = 0000000300000000000000F1, lsn = 0/F1000120
2026-10-14 19:04:42.564 P00   INFO: check archive for segment(s) 0000000300000000000000F1:0000000300000000000000F1
2026-10-14 19:04:42.725 P00   INFO: new backup label = 20261014-190233F_20261014-190441I
2026-10-14 19:04:42.953 P00   INFO: incr backup size = 634.9KB, file total = 2223
2026-10-14 19:04:42.953 P00   INFO: backup command end: completed successfully (1456ms)
2026-10-14 19:04:42.954 P00   INFO: expire command begin 2.59.3: --exec-id=7584-6e3c22e0 --log-level-console=info --repo1-path=/var/lib/pgbackrest --repo1-retention-full=2 --stanza=lab
2026-10-14 19:04:42.967 P00   INFO: expire command end: completed successfully (14ms)

-- checking the backups infos 
[vagrant@db1 ~]$ sudo -iu postgres pgbackrest info
stanza: lab
    status: ok
    cipher: none

    db (current)
        wal archive min/max (18): 0000000300000000000000EB/0000000300000000000000F1

        full backup: 20261014-190233F
            timestamp start/stop: 2026-10-14 19:02:33+01 / 2026-10-14 19:03:13+01
            wal start/stop: 0000000300000000000000ED / 0000000300000000000000ED
            database size: 901.4MB, database backup size: 901.4MB
            repo1: backup set size: 72.1MB, backup size: 72.1MB

        diff backup: 20261014-190233F_20261014-190344D
            timestamp start/stop: 2026-10-14 19:03:44+01 / 2026-10-14 19:03:45+01
            wal start/stop: 0000000300000000000000EF / 0000000300000000000000EF
            database size: 901.4MB, database backup size: 1.4MB
            repo1: backup set size: 72.1MB, backup size: 160.2KB
            backup reference total: 1 full

        incr backup: 20261014-190233F_20261014-190441I
            timestamp start/stop: 2026-10-14 19:04:41+01 / 2026-10-14 19:04:42+01
            wal start/stop: 0000000300000000000000F1 / 0000000300000000000000F1
            database size: 901.4MB, database backup size: 634.9KB
            repo1: backup set size: 72.1MB, backup size: 47KB
            backup reference total: 1 full, 1 diff

-- Performing PITR using pgBackRest 
[vagrant@db1 ~]$ sudo -iu postgres psql -d lab -c "SELECT now();"
              now
-------------------------------
 2026-10-14 19:07:05.251837+01
(1 row)


[vagrant@db1 ~]$ sudo -iu postgres psql -d lab -c "DROP TABLE apos_full;"
DROP TABLE
[vagrant@db1 ~]$ sudo -iu postgres psql -c "SELECT pg_switch_wal();"
 pg_switch_wal
---------------
 0/F2003750
(1 row)

[vagrant@db1 ~]$ sudo systemctl stop postgresql-18

-- performing the restore point in time 
sudo -iu postgres pgbackrest --stanza=lab --delta --type=time "--target=2026-10-14 19:07:05+01" --target-action=promote restore
2026-10-14 19:12:29.052 P00   INFO: restore command begin 2.59.3: --delta --exec-id=7978-aa59ac33 --log-level-console=info --pg1-path=/var/lib/pgsql/18/data --process-max=2 --repo1-path=/var/lib/pgbackrest --stanza=lab --target="2026-10-14 19:07:05+01" --target-action=promote --type=time
2026-10-14 19:12:29.088 P00   INFO: repo1: restore backup set 20261014-190233F_20261014-190441I, recovery will start at 2026-10-14 19:04:41
2026-10-14 19:12:29.105 P00   INFO: remove invalid files/links/paths from '/var/lib/pgsql/18/data'
2026-10-14 19:12:29.130 P00   INFO: remove invalid files/links/paths from '/pgdata/ts_rapida/PG_18_202506291'
2026-10-14 19:12:32.720 P00   INFO: write updated /var/lib/pgsql/18/data/postgresql.auto.conf
2026-10-14 19:12:32.774 P00   INFO: restore global/pg_control (performed last to ensure aborted restores cannot be started)
2026-10-14 19:12:32.783 P00   INFO: restore size = 901.4MB, file total = 2222
2026-10-14 19:12:32.787 P00   INFO: restore command end: completed successfully (3745ms)

[vagrant@db1 ~]$ sudo systemctl start postgresql-18

-- check the table apos_full restored 
[vagrant@db1 ~]$ sudo -iu postgres psql -d lab -c "SELECT * FROM apos_full;"
               t
-------------------------------
 2026-10-14 19:03:31.372076+01
 2026-10-14 19:04:15.239293+01
(2 rows)

-- checking the setting done by pgBackRest
[vagrant@db1 ~]$ sudo -iu postgres grep -E "restore_command|recovery_target" /var/lib/pgsql/18/data/postgresql.auto.conf
restore_command = 'cp /pgarchive/%f %p'
restore_command = 'cp /pgarchive/%f %p'
restore_command = 'pgbackrest --stanza=lab archive-get %f "%p"'
recovery_target_time = '2026-10-14 19:07:05+01'
recovery_target_action = 'promote'






