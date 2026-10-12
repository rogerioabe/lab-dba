#####################################################
## Configuration and parameters
#####################################################
1. Where a parameter value comes from

PostgreSQL reads configuration from several sources, and the last one applied wins:

Order	Source					Oracle equivalent
1	Compiled-in default			default
2	postgresql.conf (and included files)	init.ora
3	postgresql.auto.conf (via ALTER SYSTEM)	spfile
4	postgres command-line options		—
5	ALTER DATABASE ... SET			—
6	ALTER ROLE ... SET			— (in Oracle, only through a logon trigger)
7	ALTER ROLE ... IN DATABASE ... SET	—
8	SET at session level			ALTER SESSION

Levels 5 to 7 are a feature Oracle lacks. For example, you can give more work_mem to the reporting user only, without affecting anyone else.

To find where the active value came from:

sql
SELECT name, setting, unit, source, sourcefile, context
FROM pg_settings WHERE name = 'work_mem';

To catch typos in the config file before reloading, use this view. It lists every line that was parsed and whether it was applied:

sql
SELECT * FROM pg_file_settings WHERE error IS NOT NULL;

2. The parameters that matter

Memory

Parameter		Default		Starting point		Context
shared_buffers		128 MB		25% of RAM		restart
effective_cache_size	4 GB		50–75% of RAM		reload
work_mem		4 MB		16–64 MB, with caution	session
maintenance_work_mem	64 MB		256 MB to 1 GB		session

effective_cache_size doesn’t allocate any memory. It is only a planner hint for the total cache available (shared_buffers plus the OS page cache), and a higher value makes the planner more likely to choose index scans. The 4 GB default is larger than your VM’s RAM, so it should be adjusted.

WAL and checkpoints

Parameter			Default	What it does
max_wal_size			1 GB	Amount of WAL that triggers a checkpoint (soft limit)
checkpoint_timeout		5 min	Maximum time between automatic checkpoints
checkpoint_completion_target	0.9	Spreads checkpoint writes over 90% of the interval

Checkpoints that are too frequent cost I/O. As you saw in week 1, they also generate more WAL because of full_page_writes, since the first change to each page after a checkpoint writes a full page image. The classic symptom shows up in the log:

checkpoints are occurring too frequently (24 seconds apart)
HINT: Consider increasing the configuration parameter "max_wal_size".

Logging (your “eyes” in production)

Parameter			Suggested value			Purpose
log_min_duration_statement	1s				Logs slow queries
log_checkpoints			on (already the default)	Shows checkpoint frequency and duration
log_autovacuum_min_duration	10min (default) or lower	Logs long-running autovacuum runs
log_lock_waits			on				Logs lock waits longer than deadlock_timeout
log_line_prefix			‘%m [%p] %u@%d ‘		Timestamp, PID, user and database on every line
