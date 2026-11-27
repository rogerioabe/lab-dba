   -- 02-seed.sql: a small internal knowledge base
   INSERT INTO kb.documents (title, content) VALUES
     ('Vacuum',       'Autovacuum removes dead tuples and prevents transaction ID wraparound. Tune autovacuum_vacuum_scale_factor for large tables.'),
     ('Backup',       'Our backup policy: pg_dump runs every night at 02:00 and the dump files are kept for 7 days.'),
     ('Replication',  'Streaming replication sends WAL from the primary to the standby servers. Patroni manages failover.'),
     ('Indexes',      'B-tree indexes speed up equality and range queries. Use EXPLAIN ANALYZE to confirm the index is used.'),
     ('Security',     'Row-level security policies restrict which rows each tenant can read. Key the policy on the login.'),
     ('Connections',  'pg_hba.conf decides who may connect, from where and how. The first matching line wins.');
