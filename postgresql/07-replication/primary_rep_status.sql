SELECT application_name,
       state,
       pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), sent_lsn))   AS falta_enviar,
       pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), flush_lsn))  AS falta_gravar,
       pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn)) AS falta_aplicar,
       write_lag, flush_lag, replay_lag
FROM pg_stat_replication;
