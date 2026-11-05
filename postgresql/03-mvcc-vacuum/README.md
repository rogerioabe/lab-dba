#################################################
## MVCC, VACUUM and BLOAT
#################################################
1. VACUUM types

Command		What it does					Lock							Returns space to the OS?
VACUUM		Marks space used by dead tuples as reusable	SHARE UPDATE EXCLUSIVE: reads and writes continue	No, except empty pages at the end of the file (truncation)
VACUUM FULL	Rewrites the entire table in compacted form	ACCESS EXCLUSIVE: blocks everything, including reads	Yes
VACUUM ANALYZE	VACUUM + statistics collection			SHARE UPDATE EXCLUSIVE					No (same as VACUUM)
ANALYZE		Statistics only (the equivalent of DBMS_STATS)	SHARE UPDATE EXCLUSIVE					—

Every row version (tuple) is tracked through the ctid, xmin and xmax system columns. This analogy sums up PostgreSQL MVCC well:

Column	Analogy	Set by
xmin	date of birth	the transaction that INSERTed the row, or created the new version in an UPDATE
xmax	date of death	the transaction that DELETEd the row, or superseded the version in an UPDATE
ctid	current address	the physical location: block number and item offset within the page

How PostgreSQL reacts to relfrozenxid age
-----------------------------------------
Age					Level		Behavior
200 million(autovacuum_freeze_max_age)	🟡 Preventive	Forced anti-wraparound autovacuum, even if autovacuum is disabled. Runs in the background, 
							but generates I/O and is not auto-cancelled by lock conflicts.
1.6 billion(vacuum_failsafe_age)	🟠 Emergency	Failsafe mode: VACUUM skips non-essential work (index vacuuming, cost-based throttling) to freeze as fast as possible.
~2 billion minus 40 million		🔴 Warning	WARNING messages in the log requesting a VACUUM.
~2 billion minus 3 million		⛔ Shutdown	The database refuses to assign new XIDs, so writes are rejected.

Example:

The table has relfrozenxid = 1,000 and the current XID is 151,000,000, so its age is 151 million.
An aggressive VACUUM scans the table: it removes dead tuples and freezes live tuples older than, say, XID 101,000,000 (governed by vacuum_freeze_min_age).
No tuple now depends on XIDs below 101 million, so relfrozenxid advances to 101,000,000 and the age drops to 50 million.
XIDs 1,000 through 101 million can safely be reused after wraparound, because nothing references them anymore.

To check the database-level frozen XID age:

sql
SELECT datname, age(datfrozenxid) FROM pg_database;

2. Autovacuum triggers when dead tuples exceed autovacuum_vacuum_threshold + autovacuum_vacuum_scale_factor × reltuples, which by default is 50 rows + 20% of the table.
It can be tuned per table:

sql
ALTER TABLE pedidos SET (autovacuum_vacuum_scale_factor = 0.01);

Long-running transactions, including forgotten sessions left “idle in transaction”, and long reports hold back the xmin horizon. Autovacuum still runs, but it can’t remove dead tuples that are newer than the oldest open snapshot. Those tuples are only cleaned up after that transaction finishes, which leads to bloat.
Autovacuum itself does not need an exclusive lock. However, it is blocked by DDL and other operations that take stronger locks, and it cancels itself if it is blocking someone else’s lock request.

3. fillfactor ≈ PCTFREE (inverted: fillfactor is how full the page gets, PCTFREE is how much stays free).
The default is 100%, which fills pages completely and leaves no room for HOT updates on the same page.
For update-heavy tables, lower it to 70–90% to reserve space for HOT updates:

sql
ALTER TABLE pedidos SET (fillfactor = 80);

	
Objeto	Padrão	Faixa 	permitida
Tabela 	(heap)	100		10 a 100
Índice 	B-tree	90		10 a 100
Índice 	hash	75		10 a 100
Índice 	GiST	90		10 a 100


prompt do psql
==============
O último caractere do prompt mostra o tipo de usuário:

Prompt	Significado
vendas=>	usuário comum
vendas=#	superusuário
vendas=*> / vendas=*#	o * indica transação aberta
vendas=!>	transação com erro, que precisa de ROLLBACK
vendas->	comando incompleto, faltando o ;
