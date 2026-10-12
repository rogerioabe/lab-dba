###################################################
## Logical and physical backup
###################################################
-- Two worlds

			Logical							Physical
Tool			pg_dump / pg_dumpall					pg_basebackup (+ archived WAL)
Oracle equivalent	Data Pump (expdp/impdp)					RMAN + archivelog
What it copies		SQL statements / object data				The files of the entire cluster
Granularity		Database, schema or table				Whole cluster only (you can’t back up a single database)
Recovers to		The point in time of the dump				Any point in time, with WAL (PITR, week 6)
Typical use cases	Migrations, copying objects, cross-version upgrades	Production backup strategy, building replicas

The rule that comes up in interviews: pg_dump is not a production backup strategy, because it can’t do point-in-time recovery. It is a complement, just like expdp in Oracle.

2. Logical backup

pg_dump exports a single database as a consistent snapshot. It opens a transaction with a snapshot, similar to FLASHBACK_SCN in expdp, and doesn’t block normal reads and writes. It does take ACCESS SHARE locks, though, so DDL such as ALTER or DROP on the dumped tables waits until it finishes.

Format		Option		Characteristics
Plain		-Fp (default)	Human-readable SQL script; restored with psql
Custom		-Fc		Compressed; restored with pg_restore, allows selective restore
Directory	-Fd		One file per table; supports parallel dump (-j)
Tar		-Ft		Like directory, but packed into a single tar file

In practice, use -Fc for small and medium databases and -Fd -j N for large ones. pg_restore -j works with both custom and directory formats.

pg_dumpall exports the entire cluster as plain SQL. Its most important use is --globals-only: roles and tablespaces don’t belong to any database, so pg_dump doesn’t include them. Forgetting the globals is the classic mistake when restoring a dump on a new server, and it ends in “role does not exist”.
It's usefull for exporting roles and tablespaces before the databases.
For an export database combination, you has to use both pg_dumpall --global-only + pg_dump database. Para restaurar, psql globais.sql then pg_restore data.dmp in a row.

3. Physical backup

A recoverable physical backup needs two pieces, exactly as in Oracle:

WAL archiving, the equivalent of ARCHIVELOG mode: every completed WAL segment is copied to a safe location.
Base backup, an online (“hot”) copy of the data files, taken with pg_basebackup.

To restore: base backup + replay of archived WAL brings the database forward to the last available WAL segment, or to a target point of your choice.

Archiving configuration:

Parameter		Value										Context
wal_level		replica (default)								restart
archive_mode		on										restart
archive_command		command that copies %p (file path) to the destination as %f (file name)		reload

A golden rule for archive_command: it must never overwrite an existing file, and it must return a non-zero exit code if the copy fails. On failure, PostgreSQL retries and does not recycle that WAL segment. That is why the command we will use starts with test ! -f.

New since PG 17: pg_basebackup supports incremental backups, similar to RMAN level 0 and level 1, and pg_combinebackup merges them into a full backup. Incremental backups require summarize_wal = on. This is covered in later weeks, but it’s worth knowing it exists.


-- usefull option guide
pg_dump e pg_restore
====================
Opção	Significado			Mnemônico
-Fc	formato custom			o padrão para a maioria dos casos
-Fd	formato directory		o único que aceita -j no dump
-j N	paralelismo			jobs
-C	inclui CREATE DATABASE		C maiúsculo = Create
-c	inclui DROP antes dos CREATE	c minúsculo = clean
-a	só dados			data-only
-s	só estrutura			schema-only
-n	filtra schema			namespace (o mesmo n do \dn)
-t	filtra tabela			table
pg_restore -l	lista o conteúdo do dump	list

pg_basebackup
=============
Opção			Significado				Mnemônico
-D			diretório de destino			Destination
-Ft / -Fp		tar / plain				igual ao pg_dump
-z			compactar				gzip
-P			mostrar o progresso			Progress
-X stream		incluir o WAL gerado durante o backup	eXtra WAL
-c fast			checkpoint imediato			checkpoint
-T old=new		remapear tablespace (só no -Fp)		Tablespace

As views pg_stat_* de WAL e backup
==================================
View			Monitora						Lado
pg_stat_archiver	arquivamento de WAL (failed_count)			primário
pg_stat_wal_receiver	recebimento de WAL pela réplica				réplica (semana 7)
pg_stat_checkpointer	checkpoints						qualquer
pg_stat_wal		volume de WAL gerado					qualquer

