-- run in primary and replica
SELECT inet_server_addr()                       AS ip,
       current_setting('cluster_name')          AS name,
       CASE WHEN pg_is_in_recovery() THEN 'REPLICA' ELSE 'PRIMARY' END AS role,
       (SELECT timeline_id FROM pg_control_checkpoint()) AS timeline,
       (SELECT count(*) FROM pg_stat_replication)        AS replicas_connected,
       (SELECT sender_host FROM pg_stat_wal_receiver)    AS sender;
