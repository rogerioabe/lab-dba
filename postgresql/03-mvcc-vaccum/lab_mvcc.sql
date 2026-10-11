--- LAB 
-- configure a extensão para medir dead tuple
sudo -iu postgres psql -d lab -c "CREATE EXTENSION pgstattuple;"
sudo -iu postgres psql -d lab -c "GRANT pg_stat_scan_tables TO dba;"

[vagrant@db1 lib]$ psql -h db1 -U dba -d lab
psql (18.6)
Type "help" for help.

lab=> \timing on
Timing is on.
lab=> CREATE TABLE bloat (id int PRIMARY KEY, v text) WITH (autovacuum_enabled = off);
CREATE TABLE
Time: 31.304 ms
lab=> INSERT INTO bloat SELECT g, md5(g::text) FROM generate_series(1, 1000000) g;
INSERT 0 1000000
Time: 13714.045 ms (00:13.714)

lab=> SELECT pg_size_pretty(pg_relation_size('bloat'));
 pg_size_pretty
----------------
 65 MB
(1 row)

Time: 3.500 ms
lab=> SELECT tuple_count, dead_tuple_count, round(dead_tuple_percent) AS pct_morto, free_percent FROM pgstattuple('bloat');
 tuple_count | dead_tuple_count | pct_morto | free_percent
-------------+------------------+-----------+--------------
     1000000 |                0 |         0 |         0.11
(1 row)

Time: 222.265 ms

lab=> UPDATE bloat SET v = v || 'x';
UPDATE 1000000
Time: 18572.087 ms (00:18.572)
lab=> UPDATE bloat SET v = v || 'x';
UPDATE 1000000
Time: 22721.143 ms (00:22.721)
lab=> SELECT pg_size_pretty(pg_relation_size('bloat'));
 pg_size_pretty
----------------
 195 MB
(1 row)

Time: 0.481 ms

lab=> SELECT tuple_count, dead_tuple_count, round(dead_tuple_percent) AS pct_morto FROM pgstattuple('bloat');
 tuple_count | dead_tuple_count | pct_morto
-------------+------------------+-----------
     1000000 |          1000000 |        30
(1 row)

Time: 336.696 ms

lab=> VACUUM VERBOSE bloat;
INFO:  vacuuming "lab.public.bloat"
INFO:  finished vacuuming "lab.public.bloat": index scans: 1
pages: 0 removed, 25000 remain, 25000 scanned (100.00% of total), 0 eagerly scanned
tuples: 1000000 removed, 1000000 remain, 0 are dead but not yet removable
removable cutoff: 797, which was 0 XIDs old when operation ended
new relfrozenxid: 796, which is 3 XIDs ahead of previous value
frozen: 1 pages from table (0.00% of total) had 37 tuples frozen
visibility map: 25000 pages set all-visible, 16666 pages set all-frozen (0 were all-visible)
index scan needed: 16667 pages from table (66.67% of total) had 1999963 dead item identifiers removed
index "bloat_pkey": pages: 5486 in total, 0 newly deleted, 0 currently deleted, 0 reusable
avg read rate: 0.000 MB/s, avg write rate: 30.570 MB/s
buffer usage: 72183 hits, 0 reads, 10960 dirtied
WAL usage: 55476 records, 21774 full page images, 64173721 bytes, 3533 buffers full
system usage: CPU: user: 0.00 s, system: 1.47 s, elapsed: 2.80 s
INFO:  vacuuming "lab.pg_toast.pg_toast_16448"
INFO:  finished vacuuming "lab.pg_toast.pg_toast_16448": index scans: 0
pages: 0 removed, 0 remain, 0 scanned (100.00% of total), 0 eagerly scanned
tuples: 0 removed, 0 remain, 0 are dead but not yet removable
removable cutoff: 797, which was 0 XIDs old when operation ended
new relfrozenxid: 797, which is 4 XIDs ahead of previous value
frozen: 0 pages from table (100.00% of total) had 0 tuples frozen
visibility map: 0 pages set all-visible, 0 pages set all-frozen (0 were all-visible)
index scan not needed: 0 pages from table (100.00% of total) had 0 dead item identifiers removed
avg read rate: 4.814 MB/s, avg write rate: 4.814 MB/s
buffer usage: 27 hits, 1 reads, 1 dirtied
WAL usage: 2 records, 1 full page images, 8479 bytes, 0 buffers full
system usage: CPU: user: 0.00 s, system: 0.00 s, elapsed: 0.00 s
VACUUM
Time: 2805.648 ms (00:02.806)

lab=> SELECT pg_size_pretty(pg_relation_size('bloat'));
 pg_size_pretty
----------------
 195 MB
(1 row)

Time: 2.890 ms

lab=> SELECT dead_tuple_count, free_percent FROM pgstattuple('bloat');
 dead_tuple_count | free_percent
------------------+--------------
                0 |        66.47
(1 row)

Time: 189.622 ms

lab=> UPDATE bloat SET v = v || 'y';
UPDATE 1000000
Time: 11584.818 ms (00:11.585)

lab=> SELECT pg_size_pretty(pg_relation_size('bloat'));
 pg_size_pretty
----------------
 195 MB
(1 row)

Time: 2.329 ms

lab=> VACUUM FULL bloat;
VACUUM
Time: 3588.757 ms (00:03.589)

lab=>
lab=> SELECT pg_size_pretty(pg_relation_size('bloat'));
 pg_size_pretty
----------------
 65 MB
(1 row)

--- execute numa segunda sessão 
lab=> BEGIN;
SELECT count(*) FROM bloat;
BEGIN
  count
---------
 1000000
(1 row)
 
Time: 1.349 ms

-- execute na primeira sessão
lab=> UPDATE bloat SET v = v || 'z';
UPDATE 1000000
Time: 10744.800 ms (00:10.745)

lab=> VACUUM VERBOSE bloat;
INFO:  vacuuming "lab.public.bloat"
INFO:  finished vacuuming "lab.public.bloat": index scans: 1
pages: 0 removed, 17680 remain, 17680 scanned (100.00% of total), 0 eagerly scanned
tuples: 1000000 removed, 1000000 remain, 0 are dead but not yet removable
removable cutoff: 800, which was 0 XIDs old when operation ended
new relfrozenxid: 799, which is 1 XIDs ahead of previous value
frozen: 0 pages from table (0.00% of total) had 0 tuples frozen
visibility map: 17680 pages set all-visible, 8333 pages set all-frozen (0 were all-visible)
index scan needed: 8334 pages from table (47.14% of total) had 1000000 dead item identifiers removed
index "bloat_pkey": pages: 5486 in total, 0 newly deleted, 0 currently deleted, 0 reusable
avg read rate: 0.052 MB/s, avg write rate: 0.104 MB/s
buffer usage: 49202 hits, 6 reads, 12 dirtied
WAL usage: 39819 records, 6 full page images, 10984325 bytes, 343 buffers full
system usage: CPU: user: 0.52 s, system: 0.34 s, elapsed: 0.89 s
INFO:  vacuuming "lab.pg_toast.pg_toast_16448"
INFO:  finished vacuuming "lab.pg_toast.pg_toast_16448": index scans: 0
pages: 0 removed, 0 remain, 0 scanned (100.00% of total), 0 eagerly scanned
tuples: 0 removed, 0 remain, 0 are dead but not yet removable
removable cutoff: 800, which was 0 XIDs old when operation ended
new relfrozenxid: 800, which is 2 XIDs ahead of previous value
frozen: 0 pages from table (100.00% of total) had 0 tuples frozen
visibility map: 0 pages set all-visible, 0 pages set all-frozen (0 were all-visible)
index scan not needed: 0 pages from table (100.00% of total) had 0 dead item identifiers removed
avg read rate: 16.552 MB/s, avg write rate: 0.000 MB/s
buffer usage: 18 hits, 1 reads, 0 dirtied
WAL usage: 1 records, 0 full page images, 258 bytes, 0 buffers full
system usage: CPU: user: 0.00 s, system: 0.00 s, elapsed: 0.00 s
VACUUM
Time: 904.421 ms

lab=> SELECT pid, usename, state, now() - xact_start AS duracao, query
FROM pg_stat_activity
WHERE state LIKE 'idle in transaction%';
  pid  | usename |        state        |     duracao     |            query
-------+---------+---------------------+-----------------+-----------------------------
 10643 | dba     | idle in transaction | 00:00:39.893476 | SELECT count(*) FROM bloat;
(1 row)

--- faça o commit na segunda sessão 
lab=*> commit;
COMMIT

Time: 59.612 ms

--- execute o VACCUM novamente e consulte na primeira sessão
lab=> VACUUM VERBOSE bloat;
INFO:  vacuuming "lab.public.bloat"
INFO:  finished vacuuming "lab.public.bloat": index scans: 0
pages: 0 removed, 17680 remain, 1 scanned (0.01% of total), 0 eagerly scanned
tuples: 0 removed, 1000000 remain, 0 are dead but not yet removable
removable cutoff: 800, which was 0 XIDs old when operation ended
frozen: 0 pages from table (0.00% of total) had 0 tuples frozen
visibility map: 0 pages set all-visible, 0 pages set all-frozen (0 were all-visible)
index scan not needed: 0 pages from table (0.00% of total) had 0 dead item identifiers removed
avg read rate: 0.000 MB/s, avg write rate: 0.000 MB/s
buffer usage: 24 hits, 0 reads, 0 dirtied
WAL usage: 0 records, 0 full page images, 0 bytes, 0 buffers full
system usage: CPU: user: 0.00 s, system: 0.00 s, elapsed: 0.00 s
INFO:  vacuuming "lab.pg_toast.pg_toast_16448"
INFO:  finished vacuuming "lab.pg_toast.pg_toast_16448": index scans: 0
pages: 0 removed, 0 remain, 0 scanned (100.00% of total), 0 eagerly scanned
tuples: 0 removed, 0 remain, 0 are dead but not yet removable
removable cutoff: 800, which was 0 XIDs old when operation ended
frozen: 0 pages from table (100.00% of total) had 0 tuples frozen
visibility map: 0 pages set all-visible, 0 pages set all-frozen (0 were all-visible)
index scan not needed: 0 pages from table (100.00% of total) had 0 dead item identifiers removed
avg read rate: 0.000 MB/s, avg write rate: 0.000 MB/s
buffer usage: 6 hits, 0 reads, 0 dirtied
WAL usage: 0 records, 0 full page images, 0 bytes, 0 buffers full
system usage: CPU: user: 0.00 s, system: 0.00 s, elapsed: 0.00 s
VACUUM
Time: 5.695 ms

lab=> SELECT pid, usename, state, now() - xact_start AS duracao, query
FROM pg_stat_activity
WHERE state LIKE 'idle in transaction%';
 pid | usename | state | duracao | query
-----+---------+-------+---------+-------
(0 rows)

Time: 3.080 ms

-- para monitoração
lab=> SELECT relname, n_live_tup, n_dead_tup, last_vacuum, last_autovacuum, n_tup_hot_upd
FROM pg_stat_user_tables ORDER BY n_dead_tup DESC;
 relname | n_live_tup | n_dead_tup |          last_vacuum          | last_autovacuum | n_tup_hot_upd
---------+------------+------------+-------------------------------+-----------------+---------------
 bloat   |    1000000 |          0 | 2026-10-11 10:04:20.042266+01 |                 |           151
 t       |          1 |          0 | 2026-10-10 13:51:43.525831+01 |                 |             3
(2 rows)

Time: 60.554 ms
lab=> SELECT datname, age(datfrozenxid) FROM pg_database;
  datname  | age
-----------+-----
 postgres  |  56
 lab       |  56
 template1 |  56
 template0 |  56
 vendas    |  56
(5 rows)

Time: 12.841 ms
