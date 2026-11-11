# Ansible — PostgreSQL HA lab as code

Lab automation with Ansible: the OS baseline, the etcd cluster, Patroni, HAProxy and the
database objects (databases, users, privileges) of the 3-node PostgreSQL 18 cluster are
managed as code from the `ctl` node.

> **Status (lesson 12, in progress):** the whole cluster (etcd + Patroni + HAProxy) was
> destroyed and rebuilt from scratch with one playbook, `site.yml`, which imports
> `cluster.yml` and `validate.yml`. Secrets live in Ansible Vault. Databases, users and privileges are
> created by `db_objects.yml` with `community.postgresql`. Next: rolling restart and
> node-by-node patching with switchover.

## Project layout

```
ansible/
├── ansible.cfg                   # how to connect: inventory, user, sudo, vault password file
├── requirements.yml              # collections the project needs (community.postgresql)
├── inventory/
│   ├── hosts.yml                 # where: postgres (db1-db3), etcd (children: postgres), haproxy (ctl, local connection)
│   └── group_vars/
│       ├── all.yml               # base packages and cluster ports
│       ├── etcd.yml              # etcd cluster token for the lab
│       └── postgres/
│           ├── vars.yml          # plain values: users and databases lists, aliases to secrets
│           └── vault.yml         # secrets only, encrypted with Ansible Vault
├── playbooks/
│   ├── site.yml                  # entry point: common -> etcd -> etcd check, then imports cluster.yml and validate.yml
│   ├── cluster.yml               # Patroni one node at a time (serial: 1) -> HAProxy + psql client on ctl
│   ├── validate.yml              # 1 leader + 2 streaming replicas, HAProxy routing (ports 5000/5001)
│   ├── db_objects.yml            # databases, users and privileges as code
│   ├── rolling_patch.yml         # day-2: patch replicas one by one, switchover, patch the old leader
│   └── tasks/patch_node.yml      # update packages + restart through Patroni + wait for replica
├── roles/
│   ├── common/                   # OS baseline: EPEL, packages, firewalld, ports
│   ├── etcd/                     # install, per-node etcd.conf, controlled restart
│   ├── patroni_cluster/          # PostgreSQL 18 + Patroni, patroni.yml per node
│   ├── haproxy/                  # HAProxy on ctl: 5000 -> primary, 5001 -> replicas
│   └── pg_client/                # psql client on ctl
└── legacy/                       # week 1 files (inventario.ini, pg-binarios.yml)
```

## How a run works

1. `ansible-playbook playbooks/site.yml`
2. Ansible reads `ansible.cfg` from the current directory and finds the inventory.
3. It reads the inventory and builds the hosts and groups.
4. It loads the variables from `inventory/group_vars/` (and decrypts `vault.yml` with the
   password file set in `ansible.cfg`).
5. Each play selects hosts by group (`hosts: postgres`, `hosts: etcd`, ...).
6. The roles run tasks, templates and handlers on each host over SSH.

| File                     | Answers                                       |
| ------------------------ | --------------------------------------------- |
| `ansible.cfg`            | **How** to connect and where the inventory is |
| `inventory/hosts.yml`    | **Where**: machines and groups                |
| `inventory/group_vars/`  | **With which values**                         |
| `playbooks/`             | **What, on whom**                             |
| `roles/`                 | **How to do it**                              |

## Variables and secrets

Data, logic and secrets are kept apart:

| File                                   | Holds                                            | Encrypted |
| -------------------------------------- | ------------------------------------------------ | --------- |
| `inventory/group_vars/postgres/vault.yml` | Secrets only (`vault_*` variables)            | Yes       |
| `inventory/group_vars/postgres/vars.yml`  | Lists of users and databases, plain aliases   | No        |
| `playbooks/*.yml`                      | Logic only: what to do with each item            | No        |

**Alias pattern.** `vars.yml` exposes each secret under a plain name, and the playbooks use
only the plain name:

```yaml
postgres_password: "{{ vault_postgres_password }}"
```

So `grep -r postgres_password` shows where a value comes from even though the vault is
encrypted, and renaming a vault variable means changing one line, not every task.

**Vault commands.**

```bash
ansible-vault view inventory/group_vars/postgres/vault.yml | cut -d: -f1   # variable names only
ansible-vault edit inventory/group_vars/postgres/vault.yml
head -1 inventory/group_vars/postgres/vault.yml                             # $ANSIBLE_VAULT;1.1;AES256
```

The vault password file (`~/.vault_pass`, mode 0600) lives outside the repository.
`.pgpass` and `.vagrant/` are never committed.

## Databases, users and privileges as code (`db_objects.yml`)

- Runs on `localhost` (ctl) and connects through **HAProxy port 5000**, which always
  reaches the Patroni primary, so the playbook does not need to know which node leads.
- Loads the vault and `vars.yml` with `vars_files` (variables in `group_vars/postgres/`
  apply only to hosts of the `postgres` group, not to `localhost`).
- Users and databases come from the `pg_users` and `pg_databases` lists in `vars.yml`
  (`loop`). Adding a user = adding two lines to `vars.yml`.
- Privileges follow the 3 layers: `CONNECT` on the database, `USAGE` on the schema,
  `SELECT` on the tables (`ALL_IN_SCHEMA` covers existing tables only).
- `no_password_changes: true` writes a password only when the user is created, so a
  second run reports `changed=0` (passwords are stored as SCRAM hashes).
- `no_log: true` hides secrets, and also the error message: comment it out while debugging.

Prerequisites on ctl:

```bash
ansible-galaxy collection install -r requirements.yml
sudo dnf install -y python3-psycopg2 --disablerepo='pgdg*'
```

## Key concepts

**Inventory (YAML).** Each group has only three keys: `hosts`, `vars` and `children`.
`children` creates a group of groups: **hosts flow up** from child to parent, and
**variables flow down** from parent to child (the more specific child wins).

**Lab inventory.**

| Group      | Hosts                         | Notes                                                |
| ---------- | ----------------------------- | ---------------------------------------------------- |
| `postgres` | db1, db2, db3 (192.168.56.11-13) | PostgreSQL 18 + Patroni                           |
| `etcd`     | children: `postgres`          | The same 3 nodes run etcd                            |
| `haproxy`  | ctl (192.168.56.10)           | `ansible_connection: local`: the control node itself |

**Variable precedence (summary).** role `defaults/` (weakest) < inventory
(`group_vars/all` < group < `host_vars`) < play (`vars`, `vars_files`) < role `vars/` <
`set_fact`/`register` < **`-e`** (always wins).

**Role directories.**

| Directory    | Purpose                                                              |
| ------------ | -------------------------------------------------------------------- |
| `tasks/`     | What the role does, in order (`main.yml` is the entry point)         |
| `handlers/`  | Run only when **notified** by a change; at the end of the play, once |
| `templates/` | `.j2` files with variables, rendered per host (`template` module)    |
| `files/`     | Static files, sent as-is (`copy` module)                             |
| `defaults/`  | Default values, meant to be overridden                               |
| `vars/`      | Internal values, high precedence                                     |
| `meta/`      | Metadata and dependencies                                            |

**etcd template.** `ETCD_INITIAL_CLUSTER` is generated from the inventory
(`groups['etcd']` + `hostvars[h]['ansible_host']` + `loop.last` for the comma).
No hostname or IP is hard-coded: adding a `db4` to the inventory is enough.

**etcd token.** `ETCD_INITIAL_CLUSTER_TOKEN` makes the ID generated at cluster creation
unique. It is only read at bootstrap; it is not a password or a secret.

**`serial: 1`.** Configures and restarts one node at a time. Without it, all 3 etcd
members would restart together, the cluster would lose quorum and Patroni would demote
the primary.

**`import_playbook`.** `site.yml` is the single entry point: it imports `cluster.yml` and
`validate.yml`, so one command builds and checks the whole cluster, while each part can
still run on its own.

**Idempotency.** Every playbook must report `changed=0` on a second run. A refactor is
validated the same way: the new code must describe exactly the same state.

## How to run

```bash
cd ~/lab-dba/ansible

# Whole cluster: site.yml runs common -> etcd -> cluster.yml -> validate.yml
ansible-playbook playbooks/site.yml --syntax-check
ansible-playbook playbooks/site.yml --check --diff      # preview: read the diff!
ansible-playbook playbooks/site.yml                     # build or converge everything
ansible-playbook playbooks/site.yml                     # idempotency: changed=0
ansible-playbook playbooks/site.yml --tags validar      # etcd validation only

# One part only
ansible-playbook playbooks/cluster.yml                  # Patroni (serial: 1) + HAProxy
ansible-playbook playbooks/validate.yml                  # cluster and routing check

# Databases, users and privileges
ansible-playbook playbooks/db_objects.yml --check --diff   # privilege tasks fail on the first preview (database not created yet)
ansible-playbook playbooks/db_objects.yml
ansible-playbook playbooks/db_objects.yml                  # idempotency: changed=0
```

## Pitfalls we actually hit

| Error                                                   | Cause                                             | Lesson                                         |
| ------------------------------------------------------- | ------------------------------------------------- | ---------------------------------------------- |
| `loop requires a list, got [[ common_firewall_ports }}` | Brackets instead of braces                        | Variables are `"{{ }}"`, quoted when the value starts with `{{` |
| Assert failed with 0 healthy members under `--check`    | The `command` module is **skipped** in check mode | `check_mode: false` on **read-only** tasks |
| `'etcd_data_dir' is undefined` in an ad hoc command     | Role `defaults/` only exist while the role runs   | Test templates with the playbook: `--check --diff --limit` |
| etcd on db1 failed: `http://IP:192.168.56.11:2380`      | The `IP` placeholder was left in the template     | `--check --diff` would have shown it first. **Read the diff.** |
| `Start request repeated too quickly`                    | systemd blocks after repeated failures            | `systemctl reset-failed etcd` before restarting |
| Warning `ansible.posix does not support Ansible 2.14`   | Collection newer than Rocky 9's ansible-core      | Harmless; or install `ansible.posix:1.5.4` |
| Variables in `group_vars/` not loaded                   | `group_vars/` in the wrong directory              | `group_vars/` must sit next to the inventory or the playbook |
| `'pg_version' is undefined`                             | The role's `defaults` directory was misnamed      | Role directory names are fixed: `defaults/main.yml` |
| Database down after reboot                              | `postgresql-18` service enabled under Patroni     | Keep `postgresql-18` **disabled**: Patroni starts PostgreSQL |
| `404` on `rhel-9_major.9_minor-x86_64`                  | A `replace` of `$releasever` also hit `$releasever_major` and `$releasever_minor` | Replace the whole segment: regex `(redhat/rhel-)[^/]+?(-\$basearch)` -> `rhel-9` |
| `nothing provides perl(IPC::Run) needed by postgresql18-devel` | `dnf` with `name: postgresql18*` and `state: latest` installs every matching package | Add `update_only: true` to update only installed packages |
| Playbook stuck on a `dnf` command | `dnf` waits for "Importing GPG key ... Is this ok" (repo metadata key, `repo_gpgcheck`) | `rpm_key` covers packages only; run `dnf -y makecache` once, use `-y` and `timeout 300` in `command` tasks |
| `dnf` looks frozen | `-q` hides progress; first metadata download after `clean` takes minutes | Check `pgrep -a dnf` and `tail /var/log/dnf.log` on the node before interrupting |

## Day-2 operations: rolling patch (`rolling_patch.yml`)

1. Asks the Patroni REST API (port 8008, `/primary`) which node leads, and groups the
   nodes with `group_by` (`patroni_primary`, `patroni_replica`).
2. Patches the replicas one at a time (`serial: 1`): `dnf` update, restart through
   `patronictl restart`, wait until `/replica` answers 200.
3. Switches the leader over to a patched replica, then patches the old leader.
4. Runs `validate.yml`.

Idempotent: with no pending updates there is no restart and no switchover.

```bash
ansible-playbook playbooks/rolling_patch.yml                         # patch if updates exist
ansible-playbook playbooks/rolling_patch.yml -e force_restart=true   # rolling restart only
```

## Day-2 operations: password rotation (`rotate_passwords.yml`)

1. Change the values in `vault.yml` (`vault_patroni_superuser_password`,
   `vault_patroni_replication_password`).
2. The playbook finds the leader and runs `ALTER ROLE` there with `community.postgresql`,
   connecting through the local socket as the OS user `postgres` (`peer`), so the old
   password is not needed.
3. It imports `cluster.yml`: the template writes the new passwords to `patroni.yml` and the
   handler **reloads** Patroni, one node at a time. No restart, no leader change.
4. It imports `validate.yml`, which connects with the new password through HAProxy.

Order matters: database first, Patroni second. Existing sessions and streaming
connections stay up; new connections use the new password.

```bash
ansible-vault edit inventory/group_vars/postgres/vault.yml
ansible-playbook playbooks/rotate_passwords.yml
```

After rotating, update `~/.pgpass` on `ctl`.
