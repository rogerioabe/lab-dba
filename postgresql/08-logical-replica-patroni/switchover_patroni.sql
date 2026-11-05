-- performing switchover 
patronictl -c /etc/patroni/patroni.yml switchover
Current cluster topology
+ Cluster: lab (7697651400992291269) ----------+----+-------------+-----+------------+-----+
| Member |      Host     |   Role  |   State   | TL | Receive LSN | Lag | Replay LSN | Lag |
+--------+---------------+---------+-----------+----+-------------+-----+------------+-----+
| db1    | 192.168.56.11 | Leader  | running   |  1 |             |     |            |     |
| db2    | 192.168.56.12 | Replica | streaming |  1 |   0/5041290 |   0 |  0/5041290 |   0 |
| db3    | 192.168.56.13 | Replica | streaming |  1 |   0/5041290 |   0 |  0/5041290 |   0 |
+--------+---------------+---------+-----------+----+-------------+-----+------------+-----+
Primary [db1]:
Candidate ['db2', 'db3'] []: db2
When should the switchover take place (e.g. 2026-10-17T17:06 )  [now]:
Are you sure you want to switchover cluster lab, demoting current leader db1? [y/N]: y
2026-10-17 16:06:55.63534 Successfully switched over to "db2"
+ Cluster: lab (7697651400992291269) --------+----+-------------+-----+------------+-----+
| Member |      Host     |   Role  |  State  | TL | Receive LSN | Lag | Replay LSN | Lag |
+--------+---------------+---------+---------+----+-------------+-----+------------+-----+
| db1    | 192.168.56.11 | Replica | stopped |    |     unknown |     |    unknown |     |
| db2    | 192.168.56.12 | Leader  | running |    |             |     |            |     |
| db3    | 192.168.56.13 | Replica | running |    |   0/50413D8 |   0 |  0/50413D8 |   0 |
+--------+---------------+---------+---------+----+-------------+-----+------------+-----+

-- checking status
patronictl -c /etc/patroni/patroni.yml list
+ Cluster: lab (7697651400992291269) ----------+----+-------------+-----+------------+-----+
| Member |      Host     |   Role  |   State   | TL | Receive LSN | Lag | Replay LSN | Lag |
+--------+---------------+---------+-----------+----+-------------+-----+------------+-----+
| db1    | 192.168.56.11 | Replica | streaming |  2 |   0/5041518 |   0 |  0/5041518 |   0 |
| db2    | 192.168.56.12 | Leader  | running   |  2 |             |     |            |     |
| db3    | 192.168.56.13 | Replica | streaming |  2 |   0/5041518 |   0 |  0/5041518 |   0 |
+--------+---------------+---------+-----------+----+-------------+-----+------------+-----+
