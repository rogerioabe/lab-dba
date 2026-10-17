-- run on primary and statndby when they are down
/usr/pgsql-18/bin/pg_controldata /var/lib/pgsql/18/data | grep -E "cluster state|TimeLineID|checkpoint location"
