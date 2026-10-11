#################################################
## MVCC, VACUUM and BLOAT
#################################################

1- Os tipos de VACUUM
Comando			O que faz											Lock									Devolve espaço ao Linux?
VACUUM			Marca o espaço das tuplas mortas como reutilizável	Leve: leituras e escritas continuam		Não, salvo páginas vazias no fim do arquivo
VACUUM FULL		Reescreve a tabela inteira, compactada				ACCESS EXCLUSIVE: bloqueia tudo			Sim
VACUUM ANALYZE	VACUUM + coleta de estatísticas						Leve									Não
ANALYZE			Só estatísticas (o DBMS_STATS)						Leve									—

Todas as tabelas são controladas pelo ctid, xmin e xmax
Essa analogia resume bem o MVCC do PostgreSQL:

Coluna	Analogia			Quem preenche
xmin	data de nascimento		a transação que fez o INSERT ou criou a nova versão no UPDATE
xmax	data de falecimento		a transação que fez o DELETE ou substituiu a versão no UPDATE
ctid	endereço atual			a posição física, página e posição na página

-- como os postgresql trata cada idade do relfrozenxid
Idade			Nível		Reação
200 milhões		🟡 Preventivo	Autovacuum forçado (anti-wraparound), mesmo com o autovacuum desligado. Roda em segundo plano, sem nenhum impacto para o usuário.
1,6 bilhão		🟠 Emergência	Failsafe: o VACUUM corta etapas para congelar o mais rápido possível.
~2 bi menos 40 mi	🔴 Aviso	Mensagens no log pedindo VACUUM.
~2 bi menos 3 mi	⛔ Parada	O banco recusa escritas.
Um exemplo:

A tabela tem relfrozenxid = 1.000, e o XID atual é 151.000.000, ou seja, a idade é 151 milhões.
O VACUUM agressivo percorre a tabela: remove as tuplas mortas e congela as vivas criadas antes de, digamos, o XID 101.000.000.
Agora nenhuma tupla depende de XIDs abaixo de 101 milhões, então o relfrozenxid passa a 101.000.000 e a idade cai para 50 milhões.
Os XIDs de 1.000 a 101 milhões estão “livres” para reuso no futuro, porque nada mais os referencia.

para checar o frozenid da base: 
SELECT datname, age(datfrozenxid) FROM pg_database;

2. Autovaccum dispara quando o número de dead tuples atinge 20% (default)
   Pode ser customizado pelo comando abaixo:
   ALTER TABLE pedidos SET (autovacuum_vacuum_scale_factor = 0.01);
   
   O autovaccum pode ser bloqueado por transações longas ou esquecidas com BEGIN aberto. Também por relatórios longos pois necessita de
   acesso exclusivo.
   Neste ultimo caso, o vaccum vai executar somente após a transação mais longa ser finalizada, o que pode aumentar o tempo de limpeza.
   
3. fillfactor = pctfree. 
    default é 100%, o que habilita o espaço de hot update para o total da pagina.
	Tabelas om muitos updates, diminuir para 70 - 90%
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
