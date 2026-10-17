-- on primary
-- check replica
SELECT application_name, state, sync_state FROM pg_stat_replication;
 application_name |   state   | sync_state
------------------+-----------+------------
 db2              | streaming | async

-- check slot
SELECT slot_name, active FROM pg_replication_slots;
 slot_name | active
-----------+--------
 slot_db2  | t

-- on replica
-- check sender
SELECT status, sender_host, sender_port, slot_name FROM pg_stat_wal_receiver;
  status   | sender_host | sender_port | slot_name
-----------+-------------+-------------+-----------
 streaming | db1         |        5432 | slot_db2

SHOW primary_conninfo;
                    primary_conninfo
---------------------------------------------------------
 host=db1 port=5432 user=replicador application_name=db2
