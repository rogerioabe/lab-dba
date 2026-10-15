SELECT
    n.nspname AS schema_name,
    c.relname,
    c.reltuples::bigint AS estimated_rows,
    s.n_dead_tup,
	trunc((n_dead_tup / c.reltuples) * 100) AS percent_dead_tup,
    trunc(current_setting('autovacuum_vacuum_threshold')::numeric
      + (current_setting('autovacuum_vacuum_scale_factor')::numeric
        * c.reltuples::numeric)) AS estimated_vacuum_trigger
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
LEFT JOIN pg_stat_user_tables s ON s.relid = c.oid
WHERE c.relkind = 'r'
AND  c.reltuples > 0 
ORDER BY estimated_rows DESC;
