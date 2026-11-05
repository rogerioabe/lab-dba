-- ansible

-- How to get all tcp ports used by Postgres and Patroni
sudo ss -ltnp | grep -E "postgres|patroni|etcd"
LISTEN 0      4096   192.168.56.11:2380      0.0.0.0:*    users:(("etcd",pid=1018,fd=3))
LISTEN 0      4096   192.168.56.11:2379      0.0.0.0:*    users:(("etcd",pid=1018,fd=7))
LISTEN 0      200          0.0.0.0:5432      0.0.0.0:*    users:(("postgres",pid=1628,fd=7))
LISTEN 0      5            0.0.0.0:8008      0.0.0.0:*    users:(("patroni",pid=785,fd=6))
LISTEN 0      4096       127.0.0.1:2379      0.0.0.0:*    users:(("etcd",pid=1018,fd=6))

### 01 - SETTING PACKAGES AND PORTS 
cd ansible 
vi vi group_vars/all.yml
common_packages:
  - vim-enhanced
  - chrony
  - python3
  - tar

common_firewall_ports:
  - 5432/tcp
  - 2379/tcp
  - 2380/tcp
  - 8008/tcp
  
### 02 - SETTING TOKEN TO DEFINE A NEW ID EVERY EACH NEW CLUSTER 
vi group_vars/etcd.yml
etcd_cluster_token: lab-etcd
etcd_initial_cluster_state: new

### 03 - DEFINING INVENTORY 
vi inventory/hosts.yml  
all:
  children:
    postgres:
      hosts:
        db1:
          ansible_host: 192.168.56.11
        db2:
          ansible_host: 192.168.56.12
        db3:
          ansible_host: 192.168.56.13
    etcd:
	  children: 
        postgres:

## sintaxe inventario:
all:                      # grupo raiz (sempre existe)
  hosts:                  # 1) hosts que pertencem DIRETAMENTE a este grupo
    nome_do_host:
      variavel: valor     #    variáveis daquele host
  vars:                   # 2) variáveis que valem para o grupo inteiro
    variavel: valor
  children:               # 3) grupos que ficam DENTRO deste grupo
    nome_do_grupo:
      hosts: ...
      vars: ...
      children: ...       #    e assim por diante, quantos níveis quiser
	  
## ordem de importancia: children > group > all ...

example:
all:
  children:
    lisboa:
      hosts:
        web1:
        web2:
    porto:
      hosts:
        web3:
    europa:               # grupo pai
      children:
        lisboa:           # sem "hosts:" aqui, só o nome do grupo
        porto:

## a atribuição ao grupo(pai) desce para os filhos caso os filhos não tenham valores definidos 
europa        → backup_hora: "02:00"
 └─ porto     → backup_hora: "03:00"
     └─ web3
 └─ lisboa    → (não define nada)
     ├─ web1
     └─ web2

|Host	     |backup_hora	 |Por quê                                         |
|------------+---------------+------------------------------------------------|
|web1, web2	 |02:00	         |Herdaram de europa, porque lisboa não redefiniu |
|web3	     |03:00	         |porto redefiniu, e o filho vence o pai          |

### 04 - SETTING THE ANSIBLE.CFG WITH THE INVENTORY AND SUDO 
vi ansible.cfg
[defaults]
inventory = inventory/hosts.yml  <== HERE! 
remote_user = vagrant
roles_path = roles
host_key_checking = False
retry_files_enabled = False

[privilege_escalation]
become = True
become_method = sudo

### 05 - SETTING THE PLAYBOOK TO CHECK NODES HEALTH
## OBS: serial: 1 will run one node per time in order to not became the cluster unavailable
vi playbooks/site.yml
---
- name: Base comum
  hosts: postgres
  roles:
    - common

- name: Cluster etcd
  hosts: etcd
  serial: 1
  roles:
    - etcd

- name: Validar o etcd
  hosts: etcd
  gather_facts: false
  tags: validar
  tasks:
    - name: Saúde dos membros
      ansible.builtin.command: >
        etcdctl --endpoints={{ groups['etcd'] | map('extract', hostvars, 'ansible_host')
        | map('regex_replace', '$', ':2379') | join(',') }} endpoint health
      register: saude
      changed_when: false
      failed_when: false
      check_mode: false 
      run_once: true

    - name: Todos os membros saudaveis
      ansible.builtin.assert:
        that: "(saude.stdout + saude.stderr).count('is healthy') == groups['etcd'] | length"
        success_msg: "etcd OK em {{ groups['etcd'] | length }} nós"
      run_once: true

### DEFINITION OF ROLES :
=============================
Estrutura de uma role Ansible
=============================

+------------+--------------------+--------------------+---------------------+---------------------+
| Pasta      | Função             | Arquivo de entrada | Quem usa / como é   | No seu laboratório  |
|            |                    |                    | chamada             | (role etcd)         |
+============+====================+====================+=====================+=====================+
| tasks/     | O que a role faz,  | main.yml           | Executada quando o  | Instalar o etcd,    |
|            | em ordem           |                    | playbook chama a    | gerar o etcd.conf,  |
|            |                    |                    | role                | garantir o serviço  |
|            |                    |                    |                     | ativo               |
+------------+--------------------+--------------------+---------------------+---------------------+
| handlers/  | Tarefas que só     | main.yml           | notify: numa tarefa | Reiniciar etcd e    |
|            | rodam se           |                    |                     | Aguardar etcd       |
|            | notificadas por    |                    |                     |                     |
|            | uma mudança; no    |                    |                     |                     |
|            | fim do play, uma   |                    |                     |                     |
|            | vez só             |                    |                     |                     |
+------------+--------------------+--------------------+---------------------+---------------------+
| templates/ | Modelos .j2        | - (um arquivo por  | Módulo template     | etcd.conf.j2, que   |
|            | (Jinja2) com       | modelo)            | (src: arquivo.j2,   | gera um arquivo     |
|            | variáveis,         |                    | sem caminho)        | diferente por nó    |
|            | preenchidos para   |                    |                     |                     |
|            | cada host          |                    |                     |                     |
+------------+--------------------+--------------------+---------------------+---------------------+
| files/     | Arquivos           | -                  | Módulos copy,       | (não usado ainda)   |
|            | estáticos,         |                    | script              |                     |
|            | enviados sem       |                    |                     |                     |
|            | alteração          |                    |                     |                     |
+------------+--------------------+--------------------+---------------------+---------------------+
| defaults/  | Variáveis com      | main.yml           | Carregadas          | Portas 2379 e 2380, |
|            | valor padrão;      |                    | automaticamente     | etcd_data_dir,      |
|            | precedência mais   |                    |                     | token padrão        |
|            | baixa, feitas para |                    |                     |                     |
|            | serem sobrescritas |                    |                     |                     |
+------------+--------------------+--------------------+---------------------+---------------------+
| vars/      | Variáveis          | main.yml           | Carregadas          | (não usado ainda)   |
|            | internas;          |                    | automaticamente     |                     |
|            | precedência alta,  |                    |                     |                     |
|            | difíceis de        |                    |                     |                     |
|            | sobrescrever       |                    |                     |                     |
+------------+--------------------+--------------------+---------------------+---------------------+
| meta/      | Metadados e        | main.yml           | Lido pelo Ansible e | (gerado pelo role   |
|            | dependências de    |                    | pelo ansible-galaxy | init)               |
|            | outras roles       |                    |                     |                     |
+------------+--------------------+--------------------+---------------------+---------------------+

### 06 -  SETTING ROLE TASKS 
vi roles/etcd/tasks/main.yml
---
- name: Instalar etcd
  ansible.builtin.dnf:
    name: etcd
    state: present
    enablerepo: pgdg-rhel9-extras

- name: Configurar etcd
  ansible.builtin.template:
    src: etcd.conf.j2
    dest: /etc/etcd/etcd.conf
    owner: root
    group: root
    mode: "0644"
  notify: Reiniciar etcd

- name: etcd habilitado e ativo
  ansible.builtin.systemd:
    name: etcd
    state: started
    enabled: true
    
### 07 - SETTING ROLE HANDLERS
vi roles/etcd/handlers/main.yml 
---
- name: Reiniciar etcd
  ansible.builtin.systemd:
    name: etcd
    state: restarted
  notify: Aguardar etcd

- name: Aguardar etcd
  ansible.builtin.wait_for:
    host: "{{ ansible_host }}"
    port: "{{ etcd_client_port }}"
    timeout: 30
    
### 08 - SETTING ROLE TEMPLATES
 vi roles/etcd/templates/etcd.conf.j2
 
# {{ ansible_managed }}
ETCD_NAME="{{ inventory_hostname }}"
ETCD_DATA_DIR="{{ etcd_data_dir }}"
ETCD_LISTEN_PEER_URLS="http://IP:{{ ansible_host }}:{{ etcd_peer_port }}"
ETCD_LISTEN_CLIENT_URLS="http://IP:{{ ansible_host }}:{{ etcd_client_port }},http://127.0.0.1:{{ etcd_client_port }}"
ETCD_INITIAL_ADVERTISE_PEER_URLS="http://IP:{{ ansible_host }}:{{ etcd_peer_port }}"
ETCD_ADVERTISE_CLIENT_URLS="http://IP:{{ ansible_host }}:{{ etcd_client_port }}"
ETCD_INITIAL_CLUSTER="{% for h in groups['etcd'] %}{{ h }}=http://{{ hostvars[h]['ansible_host'] }}:{{ etcd_peer_port }}{{ ',' if not loop.last }}{% endfor %}"
ETCD_INITIAL_CLUSTER_STATE="{{ etcd_initial_cluster_state }}"
ETCD_INITIAL_CLUSTER_TOKEN="{{ etcd_cluster_token }}"

### 09 - SETTING THE COMMOM ROLE FOR ANY ENVIRONMENT 
vi roles/common/tasks/main.yml

---
- name: Instalar EPEL
  ansible.builtin.dnf:
    name: epel-release
    state: present

- name: Instalar pacotes base
  ansible.builtin.dnf:
    name: "{{ common_packages }}"
    state: present

- name: Garantir firewalld ativo
  ansible.builtin.systemd:
    name: firewalld
    state: started
    enabled: true

- name: Liberar portas do cluster
  ansible.posix.firewalld:
    port: "{{ item }}"
    permanent:  true
    state: enabled
  loop: "{{ common_firewall_ports }}"


### 10 - CHECKING THE SETTINGS
## documentation: ansible-doc function_name   E.g. ansible-doc ansible.builtin.assert 
## VERSION 
ansible --version
ansible [core 2.14.18]
  config file = /home/vagrant/lab-dba/ansible/ansible.cfg
  configured module search path = ['/home/vagrant/.ansible/plugins/modules', '/usr/share/ansible/plugins/modules']
  ansible python module location = /usr/lib/python3.9/site-packages/ansible
  ansible collection location = /home/vagrant/.ansible/collections:/usr/share/ansible/collections
  executable location = /usr/bin/ansible
  python version = 3.9.25 (main, Aug  6 2026, 00:00:00) [GCC 11.5.0 20240719 (Red Hat 11.5.0-14)] (/usr/bin/python3)
  jinja version = 3.1.2
  libyaml = True
  
## INVENTORY 
ansible-inventory --graph
@all:
  |--@ungrouped:
  |--@postgres:
  |  |--db1
  |  |--db2
  |  |--db3
  |--@etcd:
  |  |--@postgres:
  |  |  |--db1
  |  |  |--db2
  |  |  |--db3
  
## ping 
ansible]$ ansible all -m ping
db2 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3"
    },
    "changed": false,
    "ping": "pong"
}
db3 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3"
    },
    "changed": false,
    "ping": "pong"
}
db1 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3"
    },
    "changed": false,
    "ping": "pong"
}

## sudo root 
ansible all -m command -a whoami
db2 | CHANGED | rc=0 >>
root
db3 | CHANGED | rc=0 >>
root
db1 | CHANGED | rc=0 >>
root
  
## PORTS AND TOKEN 
[vagrant@ctl ansible]$ ansible-inventory --host db1 | grep -A6 common_firewall_ports
    "common_firewall_ports": [
        "5432/tcp",
        "2379/tcp",
        "2380/tcp",
        "8008/tcp"
    ],
    "common_packages": [
[vagrant@ctl ansible]$ ansible-inventory --host db2 | grep -A6 common_firewall_ports
    "common_firewall_ports": [
        "5432/tcp",
        "2379/tcp",
        "2380/tcp",
        "8008/tcp"
    ],
    "common_packages": [
[vagrant@ctl ansible]$ ansible-inventory --host db3 | grep -A6 common_firewall_ports
    "common_firewall_ports": [
        "5432/tcp",
        "2379/tcp",
        "2380/tcp",
        "8008/tcp"
    ],
    "common_packages": [
[vagrant@ctl ansible]$ ansible db1 -m debug -a "var=etcd_cluster_token"
db1 | SUCCESS => {
    "etcd_cluster_token": "lab-etcd"
}
[vagrant@ctl ansible]$ ansible db2 -m debug -a "var=etcd_cluster_token"
db2 | SUCCESS => {
    "etcd_cluster_token": "lab-etcd"
}
[vagrant@ctl ansible]$ ansible db3 -m debug -a "var=etcd_cluster_token"
db3 | SUCCESS => {
    "etcd_cluster_token": "lab-etcd"
}

## PLAYBOOK SINTAXE (MUST SHOW NO ERRORS. WARNING IGNORABLE)
[vagrant@ctl ansible]$ ansible-playbook playbooks/site.yml --syntax-check
[WARNING]: Collection ansible.posix does not support Ansible version 2.14.18

playbook: playbooks/site.yml


## VALIDATING THE PLAYBOOK 
## -- check : only valudate
## -- diff : shows changes inside the files 
ansible-playbook playbooks/site.yml --check --diff
[WARNING]: Collection ansible.posix does not support Ansible version 2.14.18

PLAY [Base comum] ***********************************************************************************************************************************************************************************************

TASK [Gathering Facts] ******************************************************************************************************************************************************************************************
ok: [db2]
ok: [db3]
ok: [db1]

TASK [common : Instalar EPEL] ***********************************************************************************************************************************************************************************
ok: [db2]
ok: [db1]
ok: [db3]

TASK [common : Instalar pacotes base] ***************************************************************************************************************************************************************************
ok: [db2]
ok: [db3]
ok: [db1]

TASK [common : Garantir firewalld ativo] ************************************************************************************************************************************************************************
ok: [db2]
ok: [db3]
ok: [db1]

TASK [common : Liberar portas do cluster] ***********************************************************************************************************************************************************************
skipping: [db1]
skipping: [db2]
skipping: [db3]

PLAY [Cluster etcd] *********************************************************************************************************************************************************************************************

TASK [Gathering Facts] ******************************************************************************************************************************************************************************************
ok: [db1]

TASK [etcd : Instalar etcd] *************************************************************************************************************************************************************************************
ok: [db1]

TASK [etcd : Configurar etcd] ***********************************************************************************************************************************************************************************
--- before: /etc/etcd/etcd.conf
+++ after: /home/vagrant/.ansible/tmp/ansible-local-9569cot3vkx6/tmpwbyp67gd/etcd.conf.j2
@@ -1,9 +1,10 @@
+# Ansible managed
 ETCD_NAME="db1"
 ETCD_DATA_DIR="/var/lib/etcd"
-ETCD_LISTEN_PEER_URLS="http://192.168.56.11:2380"
-ETCD_LISTEN_CLIENT_URLS="http://192.168.56.11:2379,http://127.0.0.1:2379"
-ETCD_INITIAL_ADVERTISE_PEER_URLS="http://192.168.56.11:2380"
-ETCD_ADVERTISE_CLIENT_URLS="http://192.168.56.11:2379"
+ETCD_LISTEN_PEER_URLS="http://IP:192.168.56.11:2380"
+ETCD_LISTEN_CLIENT_URLS="http://IP:192.168.56.11:2379,http://127.0.0.1:2379"
+ETCD_INITIAL_ADVERTISE_PEER_URLS="http://IP:192.168.56.11:2380"
+ETCD_ADVERTISE_CLIENT_URLS="http://IP:192.168.56.11:2379"
 ETCD_INITIAL_CLUSTER="db1=http://192.168.56.11:2380,db2=http://192.168.56.12:2380,db3=http://192.168.56.13:2380"
 ETCD_INITIAL_CLUSTER_STATE="new"
-ETCD_INITIAL_CLUSTER_TOKEN="lab-etcd"
+ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster"

changed: [db1]

TASK [etcd : etcd habilitado e ativo] ***************************************************************************************************************************************************************************
ok: [db1]

RUNNING HANDLER [etcd : Reiniciar etcd] *************************************************************************************************************************************************************************
changed: [db1]

RUNNING HANDLER [etcd : Aguardar etcd] **************************************************************************************************************************************************************************
skipping: [db1]

PLAY [Cluster etcd] *********************************************************************************************************************************************************************************************

TASK [Gathering Facts] ******************************************************************************************************************************************************************************************
ok: [db2]

TASK [etcd : Instalar etcd] *************************************************************************************************************************************************************************************
ok: [db2]

TASK [etcd : Configurar etcd] ***********************************************************************************************************************************************************************************
--- before: /etc/etcd/etcd.conf
+++ after: /home/vagrant/.ansible/tmp/ansible-local-9569cot3vkx6/tmprt6c9hu0/etcd.conf.j2
@@ -1,9 +1,10 @@
+# Ansible managed
 ETCD_NAME="db2"
 ETCD_DATA_DIR="/var/lib/etcd"
-ETCD_LISTEN_PEER_URLS="http://192.168.56.12:2380"
-ETCD_LISTEN_CLIENT_URLS="http://192.168.56.12:2379,http://127.0.0.1:2379"
-ETCD_INITIAL_ADVERTISE_PEER_URLS="http://192.168.56.12:2380"
-ETCD_ADVERTISE_CLIENT_URLS="http://192.168.56.12:2379"
+ETCD_LISTEN_PEER_URLS="http://IP:192.168.56.12:2380"
+ETCD_LISTEN_CLIENT_URLS="http://IP:192.168.56.12:2379,http://127.0.0.1:2379"
+ETCD_INITIAL_ADVERTISE_PEER_URLS="http://IP:192.168.56.12:2380"
+ETCD_ADVERTISE_CLIENT_URLS="http://IP:192.168.56.12:2379"
 ETCD_INITIAL_CLUSTER="db1=http://192.168.56.11:2380,db2=http://192.168.56.12:2380,db3=http://192.168.56.13:2380"
 ETCD_INITIAL_CLUSTER_STATE="new"
-ETCD_INITIAL_CLUSTER_TOKEN="lab-etcd"
+ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster"

changed: [db2]

TASK [etcd : etcd habilitado e ativo] ***************************************************************************************************************************************************************************
ok: [db2]

RUNNING HANDLER [etcd : Reiniciar etcd] *************************************************************************************************************************************************************************
changed: [db2]

RUNNING HANDLER [etcd : Aguardar etcd] **************************************************************************************************************************************************************************
skipping: [db2]

PLAY [Cluster etcd] *********************************************************************************************************************************************************************************************

TASK [Gathering Facts] ******************************************************************************************************************************************************************************************
ok: [db3]

TASK [etcd : Instalar etcd] *************************************************************************************************************************************************************************************
ok: [db3]

TASK [etcd : Configurar etcd] ***********************************************************************************************************************************************************************************
--- before: /etc/etcd/etcd.conf
+++ after: /home/vagrant/.ansible/tmp/ansible-local-9569cot3vkx6/tmp8gvxgnj5/etcd.conf.j2
@@ -1,9 +1,10 @@
+# Ansible managed
 ETCD_NAME="db3"
 ETCD_DATA_DIR="/var/lib/etcd"
-ETCD_LISTEN_PEER_URLS="http://192.168.56.13:2380"
-ETCD_LISTEN_CLIENT_URLS="http://192.168.56.13:2379,http://127.0.0.1:2379"
-ETCD_INITIAL_ADVERTISE_PEER_URLS="http://192.168.56.13:2380"
-ETCD_ADVERTISE_CLIENT_URLS="http://192.168.56.13:2379"
+ETCD_LISTEN_PEER_URLS="http://IP:192.168.56.13:2380"
+ETCD_LISTEN_CLIENT_URLS="http://IP:192.168.56.13:2379,http://127.0.0.1:2379"
+ETCD_INITIAL_ADVERTISE_PEER_URLS="http://IP:192.168.56.13:2380"
+ETCD_ADVERTISE_CLIENT_URLS="http://IP:192.168.56.13:2379"
 ETCD_INITIAL_CLUSTER="db1=http://192.168.56.11:2380,db2=http://192.168.56.12:2380,db3=http://192.168.56.13:2380"
 ETCD_INITIAL_CLUSTER_STATE="new"
-ETCD_INITIAL_CLUSTER_TOKEN="lab-etcd"
+ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster"

changed: [db3]

TASK [etcd : etcd habilitado e ativo] ***************************************************************************************************************************************************************************
ok: [db3]

RUNNING HANDLER [etcd : Reiniciar etcd] *************************************************************************************************************************************************************************
changed: [db3]

RUNNING HANDLER [etcd : Aguardar etcd] **************************************************************************************************************************************************************************
skipping: [db3]

PLAY [Validar o etcd] *******************************************************************************************************************************************************************************************

TASK [Saúde dos membros] ****************************************************************************************************************************************************************************************
ok: [db1]

TASK [Todos os membros saudaveis] *******************************************************************************************************************************************************************************
ok: [db1] => {
    "changed": false,
    "msg": "etcd OK em 3 nós"
}

PLAY RECAP ******************************************************************************************************************************************************************************************************
db1                        : ok=11   changed=2    unreachable=0    failed=0    skipped=2    rescued=0    ignored=0
db2                        : ok=9    changed=2    unreachable=0    failed=0    skipped=2    rescued=0    ignored=0
db3                        : ok=9    changed=2    unreachable=0    failed=0    skipped=2    rescued=0    ignored=0

## RUNNING THE PLAYBOOK

ansible-playbook playbooks/site.yml
[WARNING]: Collection ansible.posix does not support Ansible version 2.14.18

PLAY [Base comum] ***********************************************************************************************************************************************************************************************

TASK [Gathering Facts] ******************************************************************************************************************************************************************************************
ok: [db2]
ok: [db1]
ok: [db3]

TASK [common : Instalar EPEL] ***********************************************************************************************************************************************************************************
ok: [db2]
ok: [db3]
ok: [db1]

TASK [common : Instalar pacotes base] ***************************************************************************************************************************************************************************
ok: [db2]
ok: [db3]
ok: [db1]

TASK [common : Garantir firewalld ativo] ************************************************************************************************************************************************************************
ok: [db2]
ok: [db3]
ok: [db1]

TASK [common : Liberar portas do cluster] ***********************************************************************************************************************************************************************
skipping: [db1]
skipping: [db2]
skipping: [db3]

PLAY [Cluster etcd] *********************************************************************************************************************************************************************************************

TASK [Gathering Facts] ******************************************************************************************************************************************************************************************
ok: [db1]

TASK [etcd : Instalar etcd] *************************************************************************************************************************************************************************************
ok: [db1]

TASK [etcd : Configurar etcd] ***********************************************************************************************************************************************************************************
ok: [db1]

TASK [etcd : etcd habilitado e ativo] ***************************************************************************************************************************************************************************
ok: [db1]

PLAY [Cluster etcd] *********************************************************************************************************************************************************************************************

TASK [Gathering Facts] ******************************************************************************************************************************************************************************************
ok: [db2]

TASK [etcd : Instalar etcd] *************************************************************************************************************************************************************************************
ok: [db2]

TASK [etcd : Configurar etcd] ***********************************************************************************************************************************************************************************
changed: [db2]

TASK [etcd : etcd habilitado e ativo] ***************************************************************************************************************************************************************************
ok: [db2]

RUNNING HANDLER [etcd : Reiniciar etcd] *************************************************************************************************************************************************************************
changed: [db2]

RUNNING HANDLER [etcd : Aguardar etcd] **************************************************************************************************************************************************************************
ok: [db2]

PLAY [Cluster etcd] *********************************************************************************************************************************************************************************************

TASK [Gathering Facts] ******************************************************************************************************************************************************************************************
ok: [db3]

TASK [etcd : Instalar etcd] *************************************************************************************************************************************************************************************
ok: [db3]

TASK [etcd : Configurar etcd] ***********************************************************************************************************************************************************************************
changed: [db3]

TASK [etcd : etcd habilitado e ativo] ***************************************************************************************************************************************************************************
ok: [db3]

RUNNING HANDLER [etcd : Reiniciar etcd] *************************************************************************************************************************************************************************
changed: [db3]

RUNNING HANDLER [etcd : Aguardar etcd] **************************************************************************************************************************************************************************
ok: [db3]

PLAY [Validar o etcd] *******************************************************************************************************************************************************************************************

TASK [Saúde dos membros] ****************************************************************************************************************************************************************************************
ok: [db1]

TASK [Todos os membros saudaveis] *******************************************************************************************************************************************************************************
ok: [db1] => {
    "changed": false,
    "msg": "etcd OK em 3 nós"
}

PLAY RECAP ******************************************************************************************************************************************************************************************************
db1                        : ok=10   changed=0    unreachable=0    failed=0    skipped=1    rescued=0    ignored=0
db2                        : ok=10   changed=2    unreachable=0    failed=0    skipped=1    rescued=0    ignored=0
db3                        : ok=10   changed=2    unreachable=0    failed=0    skipped=1    rescued=0    ignored=0

