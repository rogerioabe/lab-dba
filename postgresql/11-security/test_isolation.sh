    #!/usr/bin/env bash
    # test_isolation.sh: proves that the acme login never reaches globex data.
    # Connects as acme_app through service=rag_acme (TLS verify-full, password from ~/.pgpass).
    # Exit code 0 = isolation holds, 1 = leak found.

    fail=0

    # Test 1: a plain read must not return rows of other tenants
    n=$(psql -X -At "service=rag_acme" -c "SELECT count(*) FROM rag.documents WHERE tenant <> 'acme'")
    if [ "$n" = "0" ]; then echo "PASS  read: acme sees no globex rows"
    else echo "FAIL  read: acme sees $n foreign rows"; fail=1; fi

    # Test 2: the vector search (top 3 nearest) must return only acme rows
    n=$(psql -X -At "service=rag_acme" -c "
        SELECT count(*) FROM (
            SELECT tenant FROM rag.documents
            ORDER BY embedding <=> '[1,0,0]' LIMIT 3) AS top
        WHERE tenant <> 'acme'")
    if [ "$n" = "0" ]; then echo "PASS  vector search: only acme rows in the top 3"
    else echo "FAIL  vector search: $n foreign rows in the top 3"; fail=1; fi

    # Test 3: writing a row into globex must be refused
    if psql -X -q "service=rag_acme" -c "INSERT INTO rag.documents (tenant, title, embedding)
                                         VALUES ('globex', 'planted', '[1,0,0]')" 2>/dev/null
    then echo "FAIL  write: acme inserted a globex row"; fail=1
    else echo "PASS  write: insert into globex refused"; fi

    # Test 4: declaring another tenant in a session variable must change nothing
    n=$(PGOPTIONS="-c app.tenant=globex" psql -X -At "service=rag_acme" \
        -c "SELECT count(*) FROM rag.documents WHERE tenant <> 'acme'")
    if [ "$n" = "0" ]; then echo "PASS  variable: SET app.tenant=globex has no effect"
    else echo "FAIL  variable: acme sees $n globex rows after setting app.tenant"; fail=1; fi

    # Test 5: switching identity with SET ROLE must be refused
    if psql -X -q "service=rag_acme" -c "SET ROLE globex_app" 2>/dev/null
    then echo "FAIL  set role: acme became globex_app"; fail=1
    else echo "PASS  set role: SET ROLE globex_app refused"; fi

    exit $fail
