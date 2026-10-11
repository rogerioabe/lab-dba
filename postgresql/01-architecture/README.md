-- architeture concepts
Shared:
======
shared_buffers: cache de páginas de dados de 8 KB.
wal_buffers: área do WAL antes de ir para o disco.
Tabela de locks, estado das transações e estruturas de controle.

Por backend:
===========
work_mem: memória para cada operação de sort ou hash. Uma query complexa pode usar várias vezes o work_mem, multiplicado pelo número de conexões. Errar esse dimensionamento é causa clássica de OOM.
maintenance_work_mem: usado por VACUUM, CREATE INDEX e afins.
temp_buffers: para tabelas temporárias.

Processo			O que faz									Oracle
checkpointer			Grava todas as páginas sujas a cada checkpoint e marca o ponto de recuperação	CKPT + DBWn em checkpoint
background writer		Grava páginas sujas aos poucos, para os backends acharem buffers livres		DBWn
walwriter			Descarrega os WAL buffers para o disco						LGWR
autovacuum launcher + workers	VACUUM e ANALYZE automáticos							— (e o job de estatísticas)
archiver			Copia os segmentos de WAL cheios (com archive_mode=on)				ARCn
walsender / walreceiver		Enviam e recebem WAL na replicação						Processos de transporte do Data Guard
io workers (PG 18)		I/O assíncrono de leitura							—
logger				Grava o log de texto (logging_collector)					alert log

Armazenamento físico

O diretório de dados é o $PGDATA (no seu laboratório, /var/lib/pgsql/18/data). Os itens principais:
Item			Conteúdo							Oracle
base/			Uma subpasta por banco, com o nome igual ao OID do banco	datafiles
global/			Catálogos do cluster inteiro, como pg_database			SYSTEM tablespace (parte)
pg_wal/			Segmentos de WAL						online redo logs
pg_xact/		Status de commit de cada transação				— (no Oracle fica no undo header)
pg_tblspc/		Links simbólicos para tablespaces				—
postgresql.auto.conf	O que você grava com ALTER SYSTEM				spfile
postmaster.pid		Lock file com PID, porta e segmento de memória; não existe com o servidor parado	—

-- check which parameter demands restart, reload or is online to persist the change
lab=> SELECT name, context FROM pg_settings
WHERE name IN ('listen_addresses','shared_buffers','work_mem','log_min_duration_statement');
            name            |  context
----------------------------+------------
 listen_addresses           | postmaster
 log_min_duration_statement | superuser
 shared_buffers             | postmaster
 work_mem                   | user
(4 rows)

postmaster - Restart
sighup - Reload (SELECT pg_reload_conf(); ou systemctl reload) - eg. pg_hba.conf, log_min_duration_statement
user/superuser - online 

-- check pending changes 
lab=> SELECT name, setting, pending_restart FROM pg_settings WHERE pending_restart;
 name | setting | pending_restart
------+---------+-----------------
(0 rows)

-- check current connection 
lab=> \conninfo
      Connection Information
      Parameter       |   Value
----------------------+-----------
 Database             | lab
 Client User          | dba
 Host                 | db1
 Host Address         | 127.0.1.1
 Server Port          | 5432
 Options              |
 Protocol Version     | 3.0
 Password Used        | true
 GSSAPI Authenticated | false
 Backend PID          | 4586
 SSL Connection       | false
 Superuser            | off
 Hot Standby          | off
(13 rows)


-- connections methods in pg_hba.conf 
Método			Verifica
trust			nada (perigoso)
peer			usuário do Linux = role (só conexão local)
scram-sha-256	senha com hash forte (padrão atual)
md5				senha (legado, sendo descontinuado)
reject			bloqueia




SELECT name, context FROM pg_settings WHERE name IN ('listen_addresses','shared_buffers','work_mem','log_min_duration_statement');"
ALTER SYSTEM SET shared_buffers = '256MB';"
SELECT pg_reload_conf();"
SELECT name, setting, pending_restart FROM pg_settings WHERE name = 'shared_buffers';"
gresql-18
SHOW shared_buffers;"

####################################
## TABLE CONCEPTS 
####################################
-- table concepts: each file table has 01GB. A new file with 01GB will be created when its limit hits.
-- Huge columns is managed in TOAST tables, similar to LOB objects
-- Index has its own file as well

-- check table physical path 
SELECT pg_relation_filepath('table_name');

 pg_relation_filepath
----------------------
 base/16390/16391
(1 row)

[postgres@db1 16390]$ ll /var/lib/pgsql/18/data/base/16390/16391*
-rw-------. 1 postgres postgres  8192 Oct 10 13:54 /var/lib/pgsql/18/data/base/16390/16391
-rw-------. 1 postgres postgres 24576 Oct 10 13:54 /var/lib/pgsql/18/data/base/16390/16391_fsm <== free space map
-rw-------. 1 postgres postgres  8192 Oct 10 13:54 /var/lib/pgsql/18/data/base/16390/16391_vm <== visibility map (dead tuples)


-- Onde está fisicamente a tabela t do laboratório?
SELECT pg_relation_filepath('t');            -- algo como base/16384/16390
SELECT oid, datname FROM pg_database;        -- confere o OID da pasta em base/
SELECT pg_relation_size('t'), pg_total_relation_size('t');

-- Processos com nome
SELECT pid, backend_type FROM pg_stat_activity;

-- Checkpoints e WAL
SELECT * FROM pg_stat_checkpointer;
SELECT pg_walfile_name(pg_current_wal_lsn());



