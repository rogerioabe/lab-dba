    # 11 — Security: TLS, pg_hba, least privilege, RLS on vectors, pgaudit, secrets

    Each control maps to a real 2026 breach pattern and has a test that proves it.

    | Breach pattern | Control | Proof |
    |---|---|---|
    | Eavesdropping / fake server | TLS, client `sslmode=verify-full` | `pg_stat_ssl`; wrong host name refused |
    | Exposed database | `pg_hba`: `hostssl` + explicit `reject` for non-TLS | non-TLS connection refused |
    | Over-privilege | `NOLOGIN` owner; app has only `SELECT`/`INSERT`; `REVOKE ... FROM PUBLIC` | `DELETE`, `CREATE`, `DROP` refused |
    | Cross-tenant leakage | RLS keyed on the login (`session_user`), `USING` + `WITH CHECK` + `FORCE`, on the vector table | `test_isolation.sh` (5 tests) |
    | No detection | pgaudit: session (`write, ddl, role`) + object (`auditor` role); trail in a separate file via pgauditlogtofile (`/var/log/pgaudit`, `0640`, group `dbaudit`) | CSV audit lines; not in the main log; unreadable outside `dbaudit` |
    | Password in code | `~/.pgpass` (0600) + `pg_service.conf`; gitleaks with a custom rule | code connects with `service=rag_acme` |

    ## Files

    | File | Purpose |
    |---|---|
    | `01-roles.sql` | database `ragdb`, roles, schema `rag` owned by `rag_owner`, toy 3-d vectors for two tenants |
    | `02-privileges.sql` | least privilege for `app_user` and `analyst` |
    | `03-rls-session-variable.sql` | version 1: tenant from a session variable (kept to show the hole) |
    | `04-tenant-logins.sql` | one login per tenant (`acme_app`, `globex_app`), group `tenants`, map `rag.tenant_members` |
    | `05-rls-by-login.sql` | version 2: `rag.my_tenants()` (SECURITY DEFINER, `session_user`) + policy `tenant_by_login` |
    | `06-audit.sql` | pgaudit session + object audit |
    | `try-as-app.sql`, `try-as-acme.sql` | manual checks |
    | `test_isolation.sh` | automated isolation test (exit 1 on leak) |
    | `pg_service.conf.example` | connection service, no secrets |
    | `../../.gitleaks.toml` | gitleaks rules + PostgreSQL URI rule |

    ## How to run

```bash
    psql -X -v ON_ERROR_STOP=1 -f 01-roles.sql
    psql -X -d ragdb -c '\password app_user'
    psql -X -d ragdb -v ON_ERROR_STOP=1 -f 02-privileges.sql
    psql -X -d ragdb -v ON_ERROR_STOP=1 -f 03-rls-session-variable.sql
    psql -X -d ragdb -c 'ALTER TABLE rag.documents FORCE ROW LEVEL SECURITY'
    psql -X -d ragdb -v ON_ERROR_STOP=1 -f 04-tenant-logins.sql
    psql -X -d ragdb -c '\password acme_app' -c '\password globex_app'
    psql -X -d ragdb -v ON_ERROR_STOP=1 -f 05-rls-by-login.sql
    ./test_isolation.sh
```

    TLS (`server.crt`/`server.key`, `ssl = on`), the two `pg_hba` lines (`app_user,+tenants`), `~/.pgpass` and `~/.pg_service.conf` are set up by hand; see the lesson steps.
    pgaudit needs `pgaudit_18` + `pgauditlogtofile_18`, `shared_preload_libraries` + restart, the `/var/log/pgaudit` folder (`2750`, group `dbaudit`, SELinux `postgresql_log_t`).

    ## Results

    - Before RLS, the nearest document to the acme question was `globex: CONFIDENTIAL merger plan`.
    - Version 1 (session variable): a session without `app.tenant` sees 0 rows and acme sees only acme rows, but **any role can declare another tenant**: both the app and `analyst` (`pg_read_all_data`) read globex after `SET app.tenant = 'globex'`.
    - Version 2 (login + `session_user`): `SET app.tenant` has no effect, `SET ROLE globex_app` is refused, tenants cannot read or change the map; writing a globex row fails with `new row violates row-level security policy`.
    - Even after a wrong `GRANT globex_app TO acme_app`, no data leaked (`session_user` does not change with `SET ROLE`); test 5 flags the misconfiguration.
    - `pg_read_all_data` does not bypass RLS; the table owner does, until `FORCE ROW LEVEL SECURITY`.
    - With RLS disabled, `test_isolation.sh` fails tests 1-4 (exit 1).
    - `sslmode=require` encrypts but accepts any certificate; only `verify-full` refuses a host-name mismatch.
    - pgaudit redacts passwords; `log_statement = ddl` logs them in clear text.
    - With pgauditlogtofile, audit lines leave the main log and go to `/var/log/pgaudit` (CSV, with user, database and client IP); the `vagrant` OS user gets `Permission denied`. Next step (AWS lessons): ship the trail off the host.
    - gitleaks default rules missed a password inside a `postgresql://` URI; a custom rule caught it.
