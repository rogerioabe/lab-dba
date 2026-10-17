===========================
Logical and physical backup
===========================

1. Two worlds
-------------

+-------------------+--------------------------------------+---------------------------------------+
|                   | Logical                              | Physical                              |
+===================+======================================+=======================================+
| Tool              | pg_dump / pg_dumpall                 | pg_basebackup (+ archived WAL)        |
+-------------------+--------------------------------------+---------------------------------------+
| Oracle equivalent | Data Pump (expdp/impdp)              | RMAN + archivelog                     |
+-------------------+--------------------------------------+---------------------------------------+
| What it copies    | SQL statements / object data         | The files of the entire cluster       |
+-------------------+--------------------------------------+---------------------------------------+
| Granularity       | Database, schema or table            | Whole cluster only (you can't back up |
|                   |                                      | a single database)                    |
+-------------------+--------------------------------------+---------------------------------------+
| Recovers to       | The point in time of the dump        | Any point in time, with WAL (PITR,    |
|                   |                                      | week 6)                               |
+-------------------+--------------------------------------+---------------------------------------+
| Typical use cases | Migrations, copying objects,         | Production backup strategy, building  |
|                   | cross-version upgrades               | replicas                              |
+-------------------+--------------------------------------+---------------------------------------+

The rule that comes up in interviews: pg_dump is not a production backup strategy, because it can't
do point-in-time recovery. It is a complement, just like expdp in Oracle.

2. Logical backup
-----------------

pg_dump exports a single database as a consistent snapshot. It opens a transaction with a snapshot,
similar to FLASHBACK_SCN in expdp, and doesn't block normal reads and writes. It does take ACCESS
SHARE locks, though, so DDL such as ALTER or DROP on the dumped tables waits until it finishes.

+-----------+---------------+------------------------------------------------+
| Format    | Option        | Characteristics                                |
+===========+===============+================================================+
| Plain     | -Fp (default) | Human-readable SQL script; restored with psql  |
+-----------+---------------+------------------------------------------------+
| Custom    | -Fc           | Compressed; restored with pg_restore, allows   |
|           |               | selective restore                              |
+-----------+---------------+------------------------------------------------+
| Directory | -Fd           | One file per table; supports parallel dump     |
|           |               | (-j)                                           |
+-----------+---------------+------------------------------------------------+
| Tar       | -Ft           | Like directory, but packed into a single tar   |
|           |               | file                                           |
+-----------+---------------+------------------------------------------------+

In practice, use -Fc for small and medium databases and -Fd -j N for large ones. pg_restore -j works
with both custom and directory formats.

pg_dumpall exports the entire cluster as plain SQL. Its most important use is --globals-only: roles
and tablespaces don't belong to any database, so pg_dump doesn't include them. Forgetting the
globals is the classic mistake when restoring a dump on a new server, and it ends in "role does not
exist".

To export a database completely, combine both tools: pg_dumpall --globals-only for roles and
tablespaces, plus pg_dump for the database itself. To restore, run them in this order: first psql -f
globals.sql, then pg_restore data.dmp.

3. Physical backup
------------------

A recoverable physical backup needs two pieces, exactly as in Oracle:

- WAL archiving, the equivalent of ARCHIVELOG mode: every completed WAL segment is copied to a safe
  location.
- Base backup, an online ("hot") copy of the data files, taken with pg_basebackup.

To restore: base backup + replay of archived WAL brings the database forward to the last available
WAL segment, or to a target point of your choice.

Archiving configuration:

+-----------------+------------------------------------------------+---------+
| Parameter       | Value                                          | Context |
+=================+================================================+=========+
| wal_level       | replica (default)                              | restart |
+-----------------+------------------------------------------------+---------+
| archive_mode    | on                                             | restart |
+-----------------+------------------------------------------------+---------+
| archive_command | command that copies %p (file path) to the      | reload  |
|                 | destination as %f (file name)                  |         |
+-----------------+------------------------------------------------+---------+

A golden rule for archive_command: it must never overwrite an existing file, and it must return a
non-zero exit code if the copy fails. On failure, PostgreSQL retries and does not recycle that WAL
segment. That is why the command we will use starts with test ! -f.

New since PG 17: pg_basebackup supports incremental backups, similar to RMAN level 0 and level 1,
and pg_combinebackup merges them into a full backup. Incremental backups require summarize_wal = on.
This is covered in later weeks, but it's worth knowing it exists.

Useful options guide
====================

pg_dump and pg_restore
----------------------

+---------------+----------------------------------------+-----------------------------------------+
| Option        | Meaning                                | Mnemonic                                |
+===============+========================================+=========================================+
| -Fc           | custom format                          | the default choice for most cases       |
+---------------+----------------------------------------+-----------------------------------------+
| -Fd           | directory format                       | the only format that supports -j when   |
|               |                                        | dumping                                 |
+---------------+----------------------------------------+-----------------------------------------+
| -j N          | parallelism                            | jobs                                    |
+---------------+----------------------------------------+-----------------------------------------+
| -C            | includes CREATE DATABASE               | uppercase C = Create                    |
+---------------+----------------------------------------+-----------------------------------------+
| -c            | includes DROP before the CREATE        | lowercase c = clean                     |
|               | statements                             |                                         |
+---------------+----------------------------------------+-----------------------------------------+
| -a            | data only                              | data-only                               |
+---------------+----------------------------------------+-----------------------------------------+
| -s            | schema only                            | schema-only                             |
+---------------+----------------------------------------+-----------------------------------------+
| -n            | filters by schema                      | namespace (same n as in \dn)            |
+---------------+----------------------------------------+-----------------------------------------+
| -t            | filters by table                       | table                                   |
+---------------+----------------------------------------+-----------------------------------------+
| pg_restore -l | lists the dump contents                | list                                    |
+---------------+----------------------------------------+-----------------------------------------+

pg_basebackup
-------------

+------------+---------------------------------------------+-----------------+
| Option     | Meaning                                     | Mnemonic        |
+============+=============================================+=================+
| -D         | target directory                            | Destination     |
+------------+---------------------------------------------+-----------------+
| -Ft / -Fp  | tar / plain                                 | same as pg_dump |
+------------+---------------------------------------------+-----------------+
| -z         | compress                                    | gzip            |
+------------+---------------------------------------------+-----------------+
| -P         | show progress                               | Progress        |
+------------+---------------------------------------------+-----------------+
| -X stream  | include the WAL generated during the backup | eXtra WAL       |
+------------+---------------------------------------------+-----------------+
| -c fast    | immediate checkpoint                        | checkpoint      |
+------------+---------------------------------------------+-----------------+
| -T old=new | remap a tablespace (plain format only)      | Tablespace      |
+------------+---------------------------------------------+-----------------+

WAL and backup pg_stat_* views
------------------------------

+----------------------+------------------------------+------------------+
| View                 | Monitors                     | Where            |
+======================+==============================+==================+
| pg_stat_archiver     | WAL archiving (failed_count) | primary          |
+----------------------+------------------------------+------------------+
| pg_stat_wal_receiver | WAL received by the replica  | replica (week 7) |
+----------------------+------------------------------+------------------+
| pg_stat_checkpointer | checkpoints (PG 17+)         | any              |
+----------------------+------------------------------+------------------+
| pg_stat_wal          | volume of WAL generated      | any              |
+----------------------+------------------------------+------------------+
