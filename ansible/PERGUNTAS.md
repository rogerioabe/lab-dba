# Aula 10 — perguntas para responder (vão para o README)

1. Desafio 3: qual fact contém o IP 192.168.56.x? Por que o ansible_default_ipv4 não serve aqui?
2. TODO 5: por que o token do lab fica em group_vars e não no defaults/ da role?
3. TODO 15: o que aconteceria com o Patroni se os 3 etcd reiniciassem juntos?
A: O Patroni perderia a referencia do Primary e o rebaixaria para evitar o slipt brain.
4. Rode com -e etcd_cluster_token=teste --check --diff. Quem venceu, e por quê?
5. Na 2ª execução, por que o handler não rodou?
