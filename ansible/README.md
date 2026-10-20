cat > ~/lab-dba/ansible/README.md <<'EOF'
# Ansible — : `common` and `etcd` roles

Lab automation with Ansible: the OS baseline and the etcd cluster on the
3 nodes (db1, db2, db3) are now managed as code.

> **Status:** the etcd cluster, built by hand in lesson 8, was **taken over**
> by Ansible (the expected diff was only the `# Ansible managed` line).
> Patroni is still manual; it comes in lesson 11.

## Project layout

```
ansible/
├── ansible.cfg               # how to connect: inventory, user, sudo
├── inventory/
│   └── hosts.yml             # where: hosts and groups (postgres; etcd = children of postgres)
├── group_vars/
│   ├── all.yml               # base packages and cluster ports
│   └── etcd.yml              # etcd cluster token for the lab
├── playbooks/
│   └── site.yml              # what, on whom: common -> etcd (serial: 1) -> validation
├── roles/
│   ├── common/               # OS baseline: EPEL, packages, firewalld, ports
│   └── etcd/                 # install, per-node etcd.conf, controlled restart
└── legado/                   # week 1 files (inventario.ini, pg-binarios.yml)
```

## How a run works

1. `ansible-playbook playbooks/site.yml`
2. Ansible reads `ansible.cfg` from the current directory and finds the inventory.
3. It reads the inventory and builds the hosts and groups.
4. It loads the variables from `group_vars/`.
5. Each play selects hosts by group (`hosts: postgres`, `hosts: etcd`).
6. The roles run tasks, templates and handlers on each host over SSH.

| File 			| Answers 					|
| --------------------- | --------------------------------------------- |
| `ansible.cfg`  	| **How** to connect and where the inventory is |
| `inventory/hosts.yml` | **Where**: machines and groups 		|
| `group_vars/` 	| **With which values** 			|
| `playbooks/site.yml` 	| **What, on whom** 				|
| `roles/` 		| **How to do it** 				|

## Key concepts

**Inventory (YAML).** Each group has only three keys: `hosts`, `vars` and
`children`. `children` creates a group of groups: **hosts flow up** from child
to parent, and **variables flow down** from parent to child (the more specific
child wins).

**Variable precedence (summary).** role `defaults/` (weakest) < inventory
(`group_vars/all` < group < `host_vars`) < play < role `vars/` <
`set_fact`/`register` < **`-e`** (always wins).

**Role directories.**

| Directory 	| Purpose 								|
| ------------- | ---------------------------------------------------------------------	|
| `tasks/` 	| What the role does, in order (`main.yml` is the entry point) 		|
| `handlers/` 	| Run only when **notified** by a change; at the end of the play, once 	|
| `templates/` 	| `.j2` files with variables, rendered per host (`template` module) 	|
| `files/` 	| Static files, sent as-is (`copy` module) 				|
| `defaults/` 	| Default values, meant to be overridden 				|
| `vars/` 	| Internal values, high precedence 					|
| `meta/` 	| Metadata and dependencies 						|

**etcd template.** `ETCD_INITIAL_CLUSTER` is generated from the inventory
(`groups['etcd']` + `hostvars[h]['ansible_host']` + `loop.last` for the comma).
No hostname or IP is hard-coded: adding a `db4` to the inventory is enough.

**etcd token.** `ETCD_INITIAL_CLUSTER_TOKEN` makes the ID generated at cluster
creation unique. It is only read at bootstrap; it is not a password or a secret.

**`serial: 1`.** Configures and restarts one node at a time. Without it, all 3
etcd members would restart together, the cluster would lose quorum and Patroni
would demote the primary.

## How to run

```bash
cd ~/lab-dba/ansible
ansible-playbook playbooks/site.yml --syntax-check
ansible-playbook playbooks/site.yml --check --diff      # preview: read the diff!
ansible-playbook playbooks/site.yml --limit db1         # apply to one node first
ansible-playbook playbooks/site.yml                     # all nodes, one at a time
ansible-playbook playbooks/site.yml                     # idempotency: changed=0
ansible-playbook playbooks/site.yml --tags validar      # etcd validation only
```

## Pitfalls we actually hit

| Error | Cause | Lesson |
| --- | --- | --- |
| `loop requires a list, got [[ common_firewall_ports }}` 	| Brackets instead of braces 				| Variables are `"{{ }}"`, quoted when the value starts with `{{`. Read the value after "|								 |					 		 |got". 										|
| Assert failed with 0 healthy members under `--check` 		| The `command` module is **skipped** in check mode 	| `check_mode: false` on **read-only** tasks 						|
| `'etcd_data_dir' is undefined` in an ad hoc command 		| Role `defaults/` only exist while the role runs 	| Test templates with the playbook: `--check --diff --limit` |
| etcd on db1 failed: `http://IP:192.168.56.11:2380` 		| The `IP` placeholder was left in the template 	| `--check --diff` would have shown it first. **Read the diff.** |
| `Start request repeated too quickly` 				| systemd blocks after repeated failures 		| `systemctl reset-failed etcd` before restarting |
| Warning `ansible.posix does not support Ansible 2.14` 	| Collection newer than Rocky 9's ansible-core 		| Harmless; or install `ansible.posix:1.5.4` |

**`ansible` / `ansible-playbook` always run on `ctl`**; the host in the command is the target.

**`postgresql-18` disabled is correct:** Patroni manages PostgreSQL. Enabling the
service would start the database outside Patroni at boot (split-brain risk).

## Lesson questions (answer in my own words)

1. Which fact holds the 192.168.56.x IP? Why doesn't `ansible_default_ipv4` work here?
2. Why does the lab token live in `group_vars` and not in the role's `defaults/`?
3. What would happen to Patroni if all 3 etcd members restarted at once?
4. With `-e etcd_cluster_token=teste --check --diff`, which value won, and why?
5. On the second run, why didn't the handler run?

