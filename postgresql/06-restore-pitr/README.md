Week 6: PITR and pgBackRest

Structure: Part I, reference theory (the full topic, as in the official course) · Part II, hands-on lab · Part III, review summary.

PART I: REFERENCE THEORY
1. What PITR is

In week 5 you restored the database up to the last available WAL segment. PITR (Point-in-Time Recovery) is the same process, except that you decide where recovery stops. It is RMAN’s RECOVER DATABASE UNTIL ...

The ingredients are the same as in week 5:

a base backup;
archived WAL from that backup up to a point past the desired target;
recovery.signal + restore_command;
and, the new piece, a recovery target.
2. Recovery parameters

Recovery targets

Parameter	Recovers to	Oracle
recovery_target_time	A timestamp: ‘2026-10-14 18:30:00+01’	UNTIL TIME
recovery_target_xid	A specific transaction ID	UNTIL SCN (roughly)
recovery_target_lsn	An exact WAL position	UNTIL SCN
recovery_target_name	A named point, created beforehand with pg_create_restore_point()	restore point
recovery_target = ‘immediate’	The earliest consistent point: the end of the backup	—

Rules:

Only one target can be set. Setting more than one prevents the server from starting.
With no target, recovery runs to the end of the available WAL, as in week 5.
Always include the time zone in recovery_target_time. Without it, the server time zone is used, and a time zone mistake shifts the target by hours.

What happens when the target is reached

recovery_target_action	Behavior
pause (default)	Stops WAL replay and leaves the database read-only. You validate the data, then run pg_wal_replay_resume() to open it.
promote	Ends recovery and opens the database for read-write right away
shutdown	Shuts the server down (useful in automation)

Why pause matters: if the timestamp was wrong, you stop the server, adjust the target and start again without re-restoring the backup, as long as the new target is further ahead. Recovery never goes backwards.

If hot_standby = off, pause behaves like shutdown, because the database can’t be opened for reads.

Other parameters

Parameter	Purpose
restore_command	How to fetch archived WAL (%f file name, %p destination path)
recovery_target_inclusive	on (default): stop just after the target; off: stop just before it. Applies to _time, _xid and _lsn.
recovery_target_timeline	latest (default since PG 12), current, or a timeline ID
recovery_end_command	Command run once, at the end of recovery
archive_cleanup_command	Removes old WAL from the archive (used on replicas, week 7)
recovery_min_apply_delay	Delays WAL apply on a replica (week 7)

All of them go in postgresql.conf or postgresql.auto.conf. recovery.conf was removed in PG 12, and recovery is now triggered by signal files.

Signal files

File	Effect
recovery.signal	Performs targeted recovery (to the target or to the end of WAL), then opens the database
standby.signal	Stays in continuous recovery, so the server acts as a replica (week 7)

If both files are present, standby.signal takes precedence.

3. Control functions
Function	Use
pg_create_restore_point(‘name’)	Creates a named point in the WAL, before deployments and data loads
pg_is_in_recovery()	true while in recovery (or on a replica)
pg_wal_replay_pause() / pg_wal_replay_resume()	Pauses / resumes WAL replay
pg_get_wal_replay_pause_state()	not paused, pause requested, or paused
pg_last_wal_replay_lsn()	Last LSN replayed
pg_last_xact_replay_timestamp()	Commit timestamp of the last replayed transaction
pg_promote()	Ends recovery and opens the database (same as pg_ctl promote)
4. How recovery works internally
Startup: PostgreSQL finds the backup_label file written by the backup, which tells it which checkpoint and LSN to start from.
WAL reading: WAL is read first from the local pg_wal directory and, when a segment isn’t found there, through restore_command.
Redo: records are replayed up to the target or to the end of the available WAL.
End of recovery: PostgreSQL writes an end-of-recovery checkpoint, switches to a new timeline, writes the .history file, and removes recovery.signal (backup_label is renamed to backup_label.old).

To inspect the state stored in the control file (pg_control, the “controlfile”):

bash
sudo -iu postgres /usr/pgsql-18/bin/pg_controldata /var/lib/pgsql/18/data

The most useful fields are “Database cluster state”, “Latest checkpoint location” and “TimeLineID”.

5. Timelines
Every completed recovery, and every replica promotion, creates a new timeline.
The reason: after going back in time, the database generates new WAL that branches off from a point in the past. With the same file names, that WAL would overwrite the original history. The new timeline changes the file names and preserves both branches.
In WAL file names, the first 8 hex characters are the timeline ID (00000002 + 16 characters for the position).
The 0000000N.history file records which timeline timeline N branched from and at which LSN. It is archived alongside the WAL segments.
In practice, you can run PITR to a point before an earlier PITR by choosing the right timeline in recovery_target_timeline.

The Oracle bridge: timelines are incarnations. Every OPEN RESETLOGS creates one, and RESET DATABASE TO INCARNATION goes back to an earlier branch.

6. The key limitation: PITR is cluster-wide

You can’t rewind a single database or a single table. To recover a dropped table without losing work done afterwards in other tables:

restore the backup with PITR on another server, or in another data directory on a different port;
export the table with pg_dump -t;
import it into production.

It’s the same principle as Oracle’s RECOVER TABLE, which does this automatically with an auxiliary instance. In PostgreSQL, you build the auxiliary instance yourself.

7. pgBackRest: the “RMAN” of PostgreSQL

Manual PITR works, but nobody manages pg_basebackup, WAL copying with cp, and retention by hand in production. pgBackRest is the industry-standard tool.

Architecture

Repository (repo): stores backups and WAL. It can be local, on a dedicated backup server (over SSH or TLS), on object storage (S3, Azure, GCS), or on SFTP.
Up to 4 repositories at once (repo1 to repo4), for example a fast local one and another on S3 for disaster recovery.
Stanza: the configuration of one cluster inside the repository, roughly like the DBID in the RMAN catalog.
Backup from a standby (backup-standby=y), to offload the primary.
Configuration: /etc/pgbackrest.conf, with a [global] section and one section per stanza.

Commands

Command	Purpose
stanza-create	Creates the stanza in the repository
stanza-upgrade	Updates the stanza after a PostgreSQL major version upgrade
stanza-delete	Removes the stanza and all its backups
check	Validates configuration and archiving end to end
backup	Takes a backup
restore	Restores, with or without PITR
info	Lists backups, their sizes and the available WAL range
expire	Applies retention (runs automatically after each backup)
verify	Verifies the integrity of files in the repository
archive-push / archive-get	Used in archive_command / restore_command
stop / start	Suspends / resumes operations (maintenance)

Backup types

Type	Copies changes since...	RMAN
full	— (everything)	Level 0
diff	the last full	Level 1 cumulative
incr	the last backup of any type	Level 1 differential
The default, with no --type, is incr. If no full backup exists yet, it automatically takes a full.
A restore needs the whole chain: full + the latest diff (if any) + the subsequent incrementals. More incrementals mean a slower restore and a more fragile chain, which is why periodic fulls are taken.
Naming trap: pgBackRest’s “differential” is RMAN’s “cumulative”, and pgBackRest’s “incremental” is RMAN’s “differential”.

Retention

Option	Purpose
repo1-retention-full	How many full backups to keep
repo1-retention-full-type	count (default) or time (in days)
repo1-retention-diff	How many differential backups to keep
repo1-retention-archive	For how many backups to keep WAL (by default, follows the retained backups)

When a full backup expires, the diff and incr backups that depend on it expire with it.

Performance and security

Option	Purpose
process-max	Parallelism for backup and restore
compress-type / compress-level	gz, lz4, zst or bz2
repo1-cipher-type=aes-256-cbc + repo1-cipher-pass	Repository encryption
start-fast=y	Immediate checkpoint (like -c fast)
archive-async=y + spool-path	Asynchronous, parallel archiving for high WAL volume

Restore options

Option	Purpose
--delta	Restores only files that differ, based on checksums: much faster
--set=label	Picks a specific backup (defaults to the latest)
--type	default (to end of WAL), time, xid, lsn, name, immediate, or standby (builds a replica)
--target	The recovery target, according to --type
--target-action	pause, promote or shutdown
--target-exclusive	Stops just before the target
--target-timeline	Selects the timeline
--db-include=dbname	Restores only selected databases; the others are restored as empty files and must be dropped. It doesn’t solve single-table recovery.
--tablespace-map / --link-map	Remaps tablespaces and symlinks to other paths

pgBackRest handles tablespaces automatically, unlike the manual restore in week 5.

Market alternatives

Tool	Characteristics
pgBackRest	The most complete; de facto standard for self-managed deployments
Barman	From EDB; built around a central backup server for many clusters
WAL-G	Lightweight, geared toward cloud and object storage
Managed services (RDS, Aurora, Cloud SQL)	The provider handles everything, and PITR becomes a console option
