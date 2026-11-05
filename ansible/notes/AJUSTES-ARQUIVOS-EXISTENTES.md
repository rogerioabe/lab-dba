# Aula 11 — ajustes nos arquivos da aula 10 (faça à mão)

1. inventory/hosts.yml — crie o grupo `haproxy` com o host `ctl`
   (ansible_host 192.168.56.10). Como o Ansible roda NA ctl, use também
   `ansible_connection: local` para esse host.

2. roles/common/tasks/main.yml — depois do EPEL, instale o repositório PGDG e
   desabilite o módulo postgresql do Rocky (copie as 2 tarefas de legado/pg-binarios.yml).
   Pergunta: por que isso passou despercebido na aula 10 e quebra agora?

3. roles/etcd — PROBLEMA DE BOOTSTRAP: o etcd só confirma que subiu quando forma
   quórum. Com `serial: 1`, o primeiro nó fica esperando os outros dois, que ainda
   nem começaram. Resultado: o playbook trava ou dá timeout na criação do zero.
   Ajuste para:
     - o START inicial rodar nos 3 nós em paralelo (tire o serial do play do etcd);
     - os RESTARTs do handler continuarem um nó por vez.
   Dica: palavra-chave `throttle` (vale para tarefas e handlers).

4. playbooks/site.yml — no final, inclua o novo playbook:
       - import_playbook: cluster.yml

5. Depois de tudo: `ansible-playbook playbooks/site.yml --syntax-check`
