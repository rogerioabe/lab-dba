==========================================================
WEEK 8: LOGICAL REPLICATION, PATRONI AND HIGH AVAILABILITY
==========================================================

Structure: Part I, reference theory | Part II, hands-on lab | Part III, review summary.

[!] Before you start: the Patroni lab rebuilds the cluster from scratch on all three nodes. If you
want to keep the lab, vendas and bench databases, take a pg_dumpall on db1 first (Part II, step 0).

PART I: REFERENCE THEORY
========================

1. Logical replication
----------------------

> What it is and how it differs from physical replication

+-----------------+---------------------------+------------------------------------------------+
|                 | Physical (week 7)         | Logical                                        |
+=================+===========================+================================================+
| What is shipped | WAL blocks, byte for byte | Row changes decoded from WAL (INSERT, UPDATE,  |
|                 |                           | DELETE, TRUNCATE)                              |
+-----------------+---------------------------+------------------------------------------------+
| Granularity     | Entire cluster            | Selected tables, down to filtered columns and  |
|                 |                           | rows                                           |
+-----------------+---------------------------+------------------------------------------------+
| Target          | Identical, read-only copy | An independent, writable database              |
+-----------------+---------------------------+------------------------------------------------+
| Versions        | Same major version        | Different versions (allows cross-major         |
|                 |                           | upgrades)                                      |
+-----------------+---------------------------+------------------------------------------------+
| Platform        | Same architecture         | Any                                            |
+-----------------+---------------------------+------------------------------------------------+
| Oracle          | Physical Data Guard       | GoldenGate / Streams                           |
+-----------------+---------------------------+------------------------------------------------+

Typical use cases:

- major version upgrades with near-zero downtime (for example, PG 16 -> PG 18);
- replicating only some tables to a reporting or integration database;
- consolidating several databases into one;
- CDC (change data capture) to Kafka and Debezium.

> Architecture

- Publication, on the source database: defines what is published.
- Subscription, on the target database: connects to the source, copies the initial data and applies
  changes continuously.
- Under the hood, the subscription creates a logical replication slot on the source and uses the
  pgoutput decoding plugin.

    -- source
    CREATE PUBLICATION pub_vendas FOR TABLE loja.pedidos, loja.clientes;
    -- or: FOR ALL TABLES  |  FOR TABLES IN SCHEMA loja  (PG 15+)
    
    -- target (the tables must already exist!)
    CREATE SUBSCRIPTION sub_vendas
      CONNECTION 'host=db1 dbname=vendas user=replicador'
      PUBLICATION pub_vendas;

> Requirements

+---------------------------+------------------------------------------------+
| Requirement               | Details                                        |
+===========================+================================================+
| wal_level = logical       | On the source; requires a restart              |
+---------------------------+------------------------------------------------+
| Free slots and walsenders | max_replication_slots and max_wal_senders on   |
|                           | the source; max_logical_replication_workers on |
|                           | the target                                     |
+---------------------------+------------------------------------------------+
| Schema on the target      | Tables must exist beforehand, because DDL is   |
|                           | not replicated (use pg_dump -s)                |
+---------------------------+------------------------------------------------+
| REPLICA IDENTITY          | To replicate UPDATE and DELETE, the table must |
|                           | be able to identify the row: the primary key   |
|                           | by default; without a PK, use REPLICA IDENTITY |
|                           | USING INDEX (a unique index) or FULL (the      |
|                           | whole row, which is slow)                      |
+---------------------------+------------------------------------------------+
| Privileges                | The connection user needs REPLICATION (or      |
|                           | superuser) and SELECT on the tables, for the   |
|                           | initial copy                                   |
+---------------------------+------------------------------------------------+

> What is not replicated

- DDL (CREATE, ALTER, DROP): schema changes must be applied manually on both sides, target first;
- sequence values: on the target they don't advance and must be adjusted at cutover during an
  upgrade;
- large objects;
- materialized views.

> Features

+--------------------------------------+------------------------------------------------+
| Feature                              | How                                            |
+======================================+================================================+
| Row filter (PG 15+)                  | CREATE PUBLICATION p FOR TABLE pedidos WHERE   |
|                                      | (valor > 100);                                 |
+--------------------------------------+------------------------------------------------+
| Column list (PG 15+)                 | FOR TABLE clientes (id, nome)                  |
+--------------------------------------+------------------------------------------------+
| Skip the initial copy                | WITH (copy_data = false)                       |
+--------------------------------------+------------------------------------------------+
| Pause / resume                       | ALTER SUBSCRIPTION s DISABLE; / ENABLE;        |
+--------------------------------------+------------------------------------------------+
| New tables in the publication        | ALTER SUBSCRIPTION s REFRESH PUBLICATION;      |
+--------------------------------------+------------------------------------------------+
| Failover-ready logical slot (PG 17+) | WITH (failover = true) +                       |
|                                      | sync_replication_slots on the physical standby |
+--------------------------------------+------------------------------------------------+

> Conflicts

The target is writable, so conflicts can happen: for example, a row inserted manually on the target
with the same PK as one arriving from the source. When that happens, the subscription's apply worker
stops and keeps retrying, with the error in the log, while the slot on the source accumulates WAL.
The ways out:

- fix the data on the target (for example, delete the duplicate row);
- or skip the offending transaction: ALTER SUBSCRIPTION s SKIP (lsn = '...'), using the LSN shown in
  the log (PG 15+).

> Monitoring

+--------+------------------------------------------------+
| Where  | Resource                                       |
+========+================================================+
| Source | pg_publication, pg_publication_tables,         |
|        | pg_replication_slots (slot_type = logical),    |
|        | pg_stat_replication                            |
+--------+------------------------------------------------+
| Target | pg_subscription, pg_stat_subscription (state   |
|        | and LSN), pg_stat_subscription_stats (errors   |
|        | and conflicts)                                 |
+--------+------------------------------------------------+

Risk: a logical slot left by an abandoned subscription retains WAL (just like a physical slot) and
holds back the VACUUM horizon on the system catalogs. When retiring a subscription for good, use
DROP SUBSCRIPTION, which also drops the slot on the source.

2. High availability: why you need a tool
-----------------------------------------

In week 7 you saw, hands-on, everything a manual failover requires: detect the failure, fence the
old primary, pick the most up-to-date replica, promote it, recreate the slots, repoint the other
replicas, reinstate the old primary and redirect the applications. Every manual step is a chance for
error (the wrong user name, pg_rewind on the wrong node). An HA tool automates this cycle and solves
the hardest problem: deciding safely who the primary is.

+----------------------------+------------------------------------------------+
| Tool                       | Approach                                       |
+============================+================================================+
| Patroni                    | Consensus through a DCS (etcd, Consul,         |
|                            | ZooKeeper, Kubernetes). The industry standard. |
+----------------------------+------------------------------------------------+
| repmgr                     | Voting among the nodes, with an optional       |
|                            | witness                                        |
+----------------------------+------------------------------------------------+
| EDB Failover Manager (EFM) | From EDB: agents + a witness node; integrated  |
|                            | with EDB Postgres                              |
+----------------------------+------------------------------------------------+
| pg_auto_failover           | A central monitor node makes the decisions     |
+----------------------------+------------------------------------------------+
| Managed services           | RDS Multi-AZ, Aurora, Cloud SQL                |
+----------------------------+------------------------------------------------+

3. Patroni: architecture
------------------------

+---------------------------------------+------------------------------------------------+
| Component                             | Role                                           |
+=======================================+================================================+
| Patroni agent (one per node)          | Controls the local PostgreSQL: starts, stops,  |
|                                       | promotes, demotes and reconfigures it          |
+---------------------------------------+------------------------------------------------+
| DCS (Distributed Configuration Store) | The cluster state: who the leader is, the      |
|                                       | dynamic configuration and the members. Usually |
|                                       | etcd with 3 or 5 nodes (an odd number, to keep |
|                                       | a majority).                                   |
+---------------------------------------+------------------------------------------------+
| Leader key                            | A DCS entry with an expiry (TTL). Only the     |
|                                       | node holding it may be primary.                |
+---------------------------------------+------------------------------------------------+
| REST API (port 8008)                  | Exposes each node's state; used by patronictl  |
|                                       | and by load balancers                          |
+---------------------------------------+------------------------------------------------+
| patronictl                            | The command-line administration tool           |
+---------------------------------------+------------------------------------------------+

-- ETCD is like votting disks + OCR
-- PATRONI is like CSS + CRSD

> The HA loop

Every loop_wait seconds (10 by default), each agent does the following:

- if it is the leader: it renews the key in the DCS. If it can't renew it (because it got isolated,
  for example), it demotes its own PostgreSQL before the key expires. This is the split-brain
  protection;
- if it is a replica: it checks that a leader exists. If the key has expired (the leader died or got
  isolated), the healthy nodes run a leader election. The winner is a node that is up to date and
  within the lag limit; it acquires the key and promotes itself.

> Loop parameters

+-------------------------+---------+------------------------------------------------+
| Parameter               | Default | Purpose                                        |
+=========================+=========+================================================+
| ttl                     | 30      | Leader key lifetime, in seconds. It is the     |
|                         |         | maximum time before a failover starts.         |
+-------------------------+---------+------------------------------------------------+
| loop_wait               | 10      | Loop interval                                  |
+-------------------------+---------+------------------------------------------------+
| retry_timeout           | 10      | Retry window for DCS or PostgreSQL failures    |
+-------------------------+---------+------------------------------------------------+
| maximum_lag_on_failover | 1 MB    | A replica lagging more than this can't be      |
|                         |         | promoted                                       |
+-------------------------+---------+------------------------------------------------+

Rule: ttl >= loop_wait + 2 x retry_timeout.

> What if the DCS itself goes down?

Without the DCS, nobody can confirm who the leader is. To stay safe, Patroni demotes the primary to
read-only: it's better to lose writes than to risk two primaries. failsafe_mode (Patroni 3+) lets
the primary keep running if it can still reach all the other members through the REST API. Bottom
line: etcd is as critical as the database and needs its own high availability.

> Features that automate what you did by hand

+-----------------------------------+------------------------------------------------+
| Week 7 (manual)                   | Patroni                                        |
+===================================+================================================+
| Build replicas with pg_basebackup | Automatic when a node joins the cluster (or    |
|                                   | via pgBackRest)                                |
+-----------------------------------+------------------------------------------------+
| Write primary_conninfo            | Rewritten on every role change                 |
+-----------------------------------+------------------------------------------------+
| Create and drop slots             | use_slots: true creates slots for all members  |
|                                   | on the leader; optional permanent slots        |
+-----------------------------------+------------------------------------------------+
| pg_rewind                         | use_pg_rewind: true reinstates the old leader  |
|                                   | automatically                                  |
+-----------------------------------+------------------------------------------------+
| Fencing                           | Self-demotion + watchdog (resets the node if   |
|                                   | the agent hangs)                               |
+-----------------------------------+------------------------------------------------+
| Configure synchronous replication | synchronous_mode: true manages                 |
|                                   | synchronous_standby_names automatically        |
+-----------------------------------+------------------------------------------------+
| Switchover with a checklist       | patronictl switchover                          |
+-----------------------------------+------------------------------------------------+

> Configuration: local vs. dynamic

+----------------------------------------+-------------+-----------------------------------+
| Type                                   | Stored in   | Changed with                      |
+========================================+=============+===================================+
| Dynamic (applies to the whole cluster) | The DCS     | patronictl edit-config            |
+----------------------------------------+-------------+-----------------------------------+
| Local (per node)                       | patroni.yml | Edit the file + patronictl reload |
+----------------------------------------+-------------+-----------------------------------+

With Patroni, don't use ALTER SYSTEM for managed parameters: Patroni overwrites the configuration.
Parameters go in patroni.yml or through edit-config.

> Synchronous mode

+-------------------------------+------------------------------------------------+
| Setting                       | Behavior                                       |
+===============================+================================================+
| synchronous_mode: true        | One synchronous replica chosen by Patroni. If  |
|                               | it goes down, Patroni switches to another one  |
|                               | or, if none is available, falls back to        |
|                               | asynchronous without blocking COMMITs.         |
+-------------------------------+------------------------------------------------+
| synchronous_mode_strict: true | Never falls back to asynchronous: without a    |
|                               | synchronous replica, writes stop. Prioritizes  |
|                               | zero RPO.                                      |
+-------------------------------+------------------------------------------------+

In synchronous mode, Patroni only promotes a synchronous replica during a failover, which guarantees
zero data loss.

> Per-node tags

+---------------------+------------------------------------------------+
| Tag                 | Effect                                         |
+=====================+================================================+
| nofailover: true    | The node is never promoted (for example, a     |
|                     | reporting replica on weaker hardware)          |
+---------------------+------------------------------------------------+
| noloadbalance: true | Excluded from the API's read endpoint          |
+---------------------+------------------------------------------------+
| clonefrom: true     | Preferred source node for building new         |
|                     | replicas                                       |
+---------------------+------------------------------------------------+
| nosync: true        | Never chosen as the synchronous replica        |
+---------------------+------------------------------------------------+

> patronictl commands

+------------------------------+------------------------------------------------+
| Command                      | Purpose                                        |
+==============================+================================================+
| list                         | Members, roles, state, timeline and lag        |
+------------------------------+------------------------------------------------+
| switchover                   | Planned leader change                          |
+------------------------------+------------------------------------------------+
| failover                     | Forced promotion (when there is no healthy     |
|                              | leader)                                        |
+------------------------------+------------------------------------------------+
| restart <cluster> [<member>] | Restarts PostgreSQL through Patroni            |
+------------------------------+------------------------------------------------+
| reload                       | Reloads the configuration                      |
+------------------------------+------------------------------------------------+
| reinit <cluster> <member>    | Rebuilds a replica from scratch                |
+------------------------------+------------------------------------------------+
| edit-config / show-config    | Dynamic configuration in the DCS               |
+------------------------------+------------------------------------------------+
| pause / resume               | Maintenance mode: Patroni stops acting (no     |
|                              | automatic failover)                            |
+------------------------------+------------------------------------------------+
| history                      | History of failovers and timelines             |
+------------------------------+------------------------------------------------+
| topology                     | Replication tree                               |
+------------------------------+------------------------------------------------+

> Application routing

Patroni knows who the leader is, but it doesn't route connections to it. The options:

+-------------------+------------------------------------------------+
| Method            | How it works                                   |
+===================+================================================+
| HAProxy           | Health-checks the REST API: GET /primary       |
|                   | returns 200 only on the leader; GET /replica   |
|                   | only on replicas. One endpoint for writes and  |
|                   | another for reads.                             |
+-------------------+------------------------------------------------+
| VIP               | vip-manager or keepalived moves a virtual IP   |
|                   | to the leader                                  |
+-------------------+------------------------------------------------+
| Multi-host driver | host=db1,db2,db3                               |
|                   | target_session_attrs=read-write in the client  |
|                   | itself                                         |
+-------------------+------------------------------------------------+
| Kubernetes        | Services are updated by Patroni                |
+-------------------+------------------------------------------------+

4. The Oracle bridge
--------------------

+--------------------------------+------------------------------------------------+
| Patroni                        | Oracle                                         |
+================================+================================================+
| Patroni (agents)               | Data Guard Broker (DMON)                       |
+--------------------------------+------------------------------------------------+
| DCS (etcd) with the leader key | Fast-Start Failover observer                   |
+--------------------------------+------------------------------------------------+
| Self-demotion without the key  | Primary shutting itself down after losing      |
|                                | contact with both the observer and the standby |
+--------------------------------+------------------------------------------------+
| maximum_lag_on_failover        | FastStartFailoverLagLimit                      |
+--------------------------------+------------------------------------------------+
| synchronous_mode               | Maximum Availability (SYNC AFFIRM)             |
+--------------------------------+------------------------------------------------+
| use_pg_rewind (reinstatement)  | REINSTATE DATABASE with Flashback              |
+--------------------------------+------------------------------------------------+
| patronictl switchover          | SWITCHOVER TO in DGMGRL                        |
+--------------------------------+------------------------------------------------+
| HAProxy / VIP                  | Role-based services / SCAN                     |
+--------------------------------+------------------------------------------------+
