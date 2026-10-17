SELECT pg_is_in_recovery()                                                AS replica,
       pg_size_pretty(pg_wal_lsn_diff(pg_last_wal_receive_lsn(),
                                      pg_last_wal_replay_lsn()))           AS recebido_nao_aplicado,
       now() - pg_last_xact_replay_timestamp()                             AS atraso_tempo;
