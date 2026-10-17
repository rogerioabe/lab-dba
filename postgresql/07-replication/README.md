==============================================================
WEEK 7: PHYSICAL (STREAMING) REPLICATION, STANDBY AND FAILOVER
==============================================================

Structure: Part I, reference theory | Part II, hands-on lab | Part III, review summary.

PART I: REFERENCE THEORY
========================

1. Concepts and the Oracle bridge
---------------------------------

PostgreSQL physical replication ships WAL from the primary to one or more replicas, which replay it
continuously. A replica is a block-for-block copy of the entire cluster.

+------------------------------------------------+------------------------------------------------+
| PostgreSQL                                     | Oracle                                         |
+================================================+================================================+
| Primary                                        | Primary database                               |
+------------------------------------------------+------------------------------------------------+
| Replica / standby                              | Physical standby                               |
+------------------------------------------------+------------------------------------------------+
| Streaming replication (WAL sent over the       | Redo transport (SYNC/ASYNC)                    |
| network in real time)                          |                                                |
+------------------------------------------------+------------------------------------------------+
| Log shipping (the replica reads WAL from the   | Archivelog shipping / FAL                      |
| archive via restore_command)                   |                                                |
+------------------------------------------------+------------------------------------------------+
| Hot standby (replica open for reads)           | Active Data Guard (no extra license in         |
|                                                | PostgreSQL!)                                   |
+------------------------------------------------+------------------------------------------------+
| Promotion (pg_promote())                       | Failover / ACTIVATE STANDBY                    |
+------------------------------------------------+------------------------------------------------+
| New timeline on promotion                      | RESETLOGS / incarnation                        |
+------------------------------------------------+------------------------------------------------+
| Replication slot                               | - (similar to the APPLIED ON STANDBY           |
|                                                | archivelog deletion policy)                    |
+------------------------------------------------+------------------------------------------------+
| Cascading replication                          | Cascaded standby                               |
+------------------------------------------------+------------------------------------------------+
| recovery_min_apply_delay                       | DELAY attribute in LOG_ARCHIVE_DEST_n          |
+------------------------------------------------+------------------------------------------------+
| Patroni (week 8)                               | Data Guard Broker + Fast-Start Failover        |
+------------------------------------------------+------------------------------------------------+

Key points:

- Replication is always cluster-wide: you can't physically replicate a single database. That is what
  logical replication is for (week 8).
- Primary and replica must run the same major version on the same architecture (compatible CPU and
  operating system).
- A replica is read-only.

2. Architecture: the processes involved
---------------------------------------

+-------------+---------+------------------------------------------------+----------+
| Process     | Where   | Role                                           | Oracle   |
+=============+=========+================================================+==========+
| walsender   | primary | Streams WAL to each replica (one per replica)  | LNS / TT |
+-------------+---------+------------------------------------------------+----------+
| walreceiver | replica | Receives WAL and writes it to the local pg_wal | RFS      |
+-------------+---------+------------------------------------------------+----------+
| startup     | replica | Continuously replays WAL (redo apply)          | MRP      |
+-------------+---------+------------------------------------------------+----------+

The connection uses the replication protocol, the same one pg_basebackup uses. That is why it
requires:

- a role with the REPLICATION attribute;
- a pg_hba.conf entry with the special keyword replication in the database field.

3. Primary-side parameters
--------------------------

+---------------------------+----------------+------------------------------------------------+
| Parameter                 | Default        | Purpose                                        |
+===========================+================+================================================+
| wal_level                 | replica        | Must be replica or logical                     |
+---------------------------+----------------+------------------------------------------------+
| max_wal_senders           | 10             | Maximum concurrent replication connections     |
|                           |                | (replicas + pg_basebackup)                     |
+---------------------------+----------------+------------------------------------------------+
| max_replication_slots     | 10             | Maximum number of slots                        |
+---------------------------+----------------+------------------------------------------------+
| wal_keep_size             | 0              | Extra WAL retained in pg_wal for replicas      |
|                           |                | without a slot                                 |
+---------------------------+----------------+------------------------------------------------+
| max_slot_wal_keep_size    | -1 (unlimited) | Cap on WAL a slot can retain. Protects the     |
|                           |                | disk from abandoned slots.                     |
+---------------------------+----------------+------------------------------------------------+
| wal_sender_timeout        | 60s            | Terminates replication connections that stop   |
|                           |                | responding                                     |
+---------------------------+----------------+------------------------------------------------+
| synchronous_standby_names | empty          | Defines which replicas are synchronous         |
+---------------------------+----------------+------------------------------------------------+
| synchronous_commit        | on             | COMMIT acknowledgment level (section 6)        |
+---------------------------+----------------+------------------------------------------------+

4. Replica-side parameters and files
------------------------------------

+------------------------------------------------+------------------------------------------------+
| Item                                           | Purpose                                        |
+================================================+================================================+
| standby.signal                                 | Signal file: "stay in continuous recovery"     |
+------------------------------------------------+------------------------------------------------+
| primary_conninfo                               | Connection string to the primary: host=...     |
|                                                | port=... user=... application_name=...         |
+------------------------------------------------+------------------------------------------------+
| primary_slot_name                              | Slot the replica uses on the primary           |
+------------------------------------------------+------------------------------------------------+
| hot_standby                                    | on (default): accepts read-only queries        |
+------------------------------------------------+------------------------------------------------+
| restore_command                                | Fallback: if streaming falls behind, fetches   |
|                                                | WAL from the archive                           |
+------------------------------------------------+------------------------------------------------+
| hot_standby_feedback                           | Tells the primary which row versions the       |
|                                                | replica still needs (section 8)                |
+------------------------------------------------+------------------------------------------------+
| max_standby_streaming_delay /                  | How long to wait before cancelling conflicting |
| max_standby_archive_delay                      | queries (default 30s)                          |
+------------------------------------------------+------------------------------------------------+
| recovery_min_apply_delay                       | Delayed replica: applies WAL only after N      |
|                                                | minutes                                        |
+------------------------------------------------+------------------------------------------------+
| archive_cleanup_command                        | Removes archived WAL the replica no longer     |
|                                                | needs                                          |
+------------------------------------------------+------------------------------------------------+
| cluster_name                                   | Instance name. Becomes the default             |
|                                                | application_name of the replication            |
|                                                | connection.                                    |
+------------------------------------------------+------------------------------------------------+

Exam rule: some replica parameters must be equal to or greater than the primary's values, otherwise
the replica won't start or pauses recovery. They are max_connections, max_worker_processes,
max_wal_senders, max_prepared_transactions and max_locks_per_transaction. The reason is that the
replica needs enough room to reproduce everything the primary records in WAL.

5. Replication slots
--------------------

Without a slot, the primary recycles WAL as usual. If the replica stays disconnected too long, the
WAL it needs is gone. It can only catch up from the archive (restore_command) or by being rebuilt.

With a physical slot, the primary retains all WAL until the replica confirms receipt. This brings
one benefit and one danger:

- [+] the replica never loses its place in the stream;
- [!] an abandoned slot retains WAL forever, until the primary's disk fills up. This is a classic
  production incident, and it's why max_slot_wal_keep_size exists.

Also remember week 3: slots can hold back the VACUUM horizon when the replica uses
hot_standby_feedback.

    SELECT slot_name, active, restart_lsn, wal_status,
           pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn)) AS retained_wal
    FROM pg_replication_slots;

wal_status can be reserved, extended, unreserved or lost. lost means the retained WAL exceeded
max_slot_wal_keep_size and the replica must be rebuilt.

6. Synchronous vs. asynchronous
-------------------------------

Asynchronous (default): COMMIT returns without waiting for the replica. It's fast, but if the
primary dies, the last transactions may not have reached the replica (RPO > 0).

Synchronous: COMMIT waits for the replica's acknowledgment, according to synchronous_commit:

+--------------------+--------------------------------------+--------------------------------------+
| synchronous_commit | COMMIT waits for...                  | Guarantee                            |
+====================+======================================+======================================+
| off                | nothing, not even the local disk     | Can lose transactions even on the    |
|                    |                                      | primary                              |
+--------------------+--------------------------------------+--------------------------------------+
| local              | local fsync                          | Doesn't wait for the replica         |
+--------------------+--------------------------------------+--------------------------------------+
| remote_write       | the replica to receive and write (no | Survives a primary crash, but not an |
|                    | fsync)                               | OS crash on the replica              |
+--------------------+--------------------------------------+--------------------------------------+
| on (default)       | the replica to write and fsync       | No data loss if the primary fails    |
+--------------------+--------------------------------------+--------------------------------------+
| remote_apply       | the replica to apply the WAL         | Reads on the replica already see the |
|                    |                                      | commit                               |
+--------------------+--------------------------------------+--------------------------------------+

Without synchronous_standby_names, on, remote_write and remote_apply behave like local.

synchronous_standby_names formats:

- 'db2' -> only db2 is synchronous;
- 'FIRST 1 (db2, db3)' -> the first available from the list, by priority;
- 'ANY 1 (db2, db3)' -> any one of the two (quorum);
- '*' -> any replica.

The names are the replicas' application_name values.

The synchronous risk: if the only synchronous replica goes down, COMMITs on the primary hang
waiting. That is why ANY 1 is used with at least two replicas, or a tool like Patroni adjusts the
configuration automatically.

The Oracle bridge: SYNC AFFIRM vs. ASYNC, and the Maximum Availability vs. Maximum Performance
protection modes.

7. Monitoring
-------------

On the primary: pg_stat_replication, one row per replica:

+------------------------------------------------+------------------------------------------------+
| Column                                         | Meaning                                        |
+================================================+================================================+
| application_name, client_addr                  | Which replica it is                            |
+------------------------------------------------+------------------------------------------------+
| state                                          | startup, catchup (lagging, catching up) or     |
|                                                | streaming (in sync)                            |
+------------------------------------------------+------------------------------------------------+
| sent_lsn -> write_lsn -> flush_lsn ->          | The stages: sent, written, flushed (fsync) and |
| replay_lsn                                     | replayed                                       |
+------------------------------------------------+------------------------------------------------+
| write_lag, flush_lag, replay_lag               | Lag at each stage, as time                     |
+------------------------------------------------+------------------------------------------------+
| sync_state                                     | async, sync, potential (candidate) or quorum   |
+------------------------------------------------+------------------------------------------------+

Lag in bytes:

    SELECT application_name,
           pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn)) AS lag
    FROM pg_stat_replication;

On the replica:

+------------------------------------------------+------------------------------------------------+
| Resource                                       | Use                                            |
+================================================+================================================+
| pg_stat_wal_receiver                           | State of the connection to the primary         |
+------------------------------------------------+------------------------------------------------+
| pg_is_in_recovery()                            | true = this is a replica                       |
+------------------------------------------------+------------------------------------------------+
| pg_last_wal_receive_lsn() /                    | How far WAL has been received / replayed       |
| pg_last_wal_replay_lsn()                       |                                                |
+------------------------------------------------+------------------------------------------------+
| pg_last_xact_replay_timestamp()                | Timestamp of the last replayed transaction.    |
|                                                | now() minus this value gives the lag, but on   |
|                                                | an idle primary it keeps growing without any   |
|                                                | real lag.                                      |
+------------------------------------------------+------------------------------------------------+

8. Query conflicts on the replica
---------------------------------

The replica replays everything the primary does, including VACUUM removing old row versions. If a
long-running query on the replica still needs those versions, a conflict occurs, and PostgreSQL
chooses between:

- pausing WAL replay (the replica falls behind), up to max_standby_streaming_delay, 30s by default;
- after that, cancelling the query: ERROR: canceling statement due to conflict with recovery.

Tuning options:

+--------------------------------+--------------------------------+--------------------------------+
| Option                         | Effect                         | Cost                           |
+================================+================================+================================+
| Increase                       | Queries live longer            | The replica lags more          |
| max_standby_streaming_delay    |                                |                                |
+--------------------------------+--------------------------------+--------------------------------+
| max_standby_streaming_delay =  | Never cancels queries          | The replica can lag            |
| -1                             |                                | indefinitely                   |
+--------------------------------+--------------------------------+--------------------------------+
| hot_standby_feedback = on      | The primary keeps row versions | Bloat on the primary (week 3's |
|                                | the replica still uses         | long-transaction problem,      |
|                                |                                | coming from the replica)       |
+--------------------------------+--------------------------------+--------------------------------+

The pg_stat_database_conflicts view, on the replica, counts cancellations by conflict type.

9. Building a replica
---------------------

Three paths, all with the same result (backup + standby.signal + primary_conninfo):

+---------------+------------------------------------------------+
| Method        | Command                                        |
+===============+================================================+
| pg_basebackup | pg_basebackup -h primary -U replicator -D      |
|               | $PGDATA -X stream -C -S slot -R                |
+---------------+------------------------------------------------+
| pgBackRest    | pgbackrest --stanza=... --type=standby restore |
+---------------+------------------------------------------------+
| Manual        | Restore any physical backup + create           |
|               | standby.signal + set primary_conninfo          |
+---------------+------------------------------------------------+

With pg_basebackup:

- -R writes standby.signal and primary_conninfo into postgresql.auto.conf;
- -C -S name creates the slot on the primary and configures it on the replica;
- watch out: it copies the primary's postgresql.auto.conf. Any leftover recovery_target_* setting
  comes along with it, which is exactly the step F trap from week 6.

10. Failover, switchover and reinstatement
------------------------------------------

Promotion:

+--------------+---------------------------+
| Method       | Command                   |
+==============+===========================+
| SQL          | SELECT pg_promote();      |
+--------------+---------------------------+
| Command line | pg_ctl promote -D $PGDATA |
+--------------+---------------------------+

The old promote_trigger_file was removed in PG 16. On promotion:

- the replica exits recovery, switches to a new timeline and starts accepting writes;
- other replicas can follow the new primary, because recovery_target_timeline = latest (the default)
  lets them cross the timeline switch.

Failover vs. switchover:

+-----------+---------------------------+------------------------------------------------+
|           | Failover                  | Switchover                                     |
+===========+===========================+================================================+
| When      | The primary has failed    | Planned role swap (maintenance)                |
+-----------+---------------------------+------------------------------------------------+
| Data loss | Possible, if asynchronous | None                                           |
+-----------+---------------------------+------------------------------------------------+
| Steps     | Promote the replica       | Cleanly shut down the primary -> confirm the   |
|           |                           | replica received everything -> promote -> turn |
|           |                           | the old primary into a replica                 |
+-----------+---------------------------+------------------------------------------------+

The split-brain risk:

If the old primary comes back after a failover and accepts writes, you end up with two primaries
holding divergent data, which is very hard to fix. Before promoting, make sure the old primary can't
come back on its own (fencing): server powered off, service disabled, IP removed. Tools like Patroni
(week 8) do this automatically.

Reinstating the old primary: pg_rewind

After a failover, the old primary usually has WAL that the new timeline never received, so it can't
simply become a replica. The options:

- Rebuild it from scratch with pg_basebackup. It's simple, but slow for large databases.
- pg_rewind "rewinds" the old primary to the point of divergence by copying only the changed blocks
  from the new primary. Afterwards it can follow the new primary as a replica.

pg_rewind requirements:

- the old primary must be stopped (since PG 13, if it wasn't shut down cleanly, pg_rewind runs crash
  recovery first automatically);
- wal_log_hints = on or data checksums enabled. In PG 18, initdb enables checksums by default, so
  your lab already meets this;
- a connection to the new primary with a user that has sufficient privileges (superuser, or a role
  granted specific functions);
- -R writes the replica configuration, just like in pg_basebackup.

The Oracle bridge: it's Flashback Database used to reinstate the old primary after a failover
(REINSTATE DATABASE in the Broker).

11. Topologies
--------------

+-------------------+------------------------------------------------+
| Topology          | Description                                    |
+===================+================================================+
| Single replica    | The basic case                                 |
+-------------------+------------------------------------------------+
| Multiple replicas | Read scaling; one can be synchronous and the   |
|                   | others asynchronous                            |
+-------------------+------------------------------------------------+
| Cascading         | A replica that feeds another replica           |
|                   | (primary_conninfo points to a replica).        |
|                   | Offloads network traffic from the primary.     |
+-------------------+------------------------------------------------+
| Delayed replica   | recovery_min_apply_delay = '4h': a "time       |
|                   | machine" against human error, such as          |
|                   | recovering from a DROP without a full PITR     |
+-------------------+------------------------------------------------+
