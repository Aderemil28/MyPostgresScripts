/*
Script  : transaction-id-wraparound.sql
Purpose : How close each database, and the oldest tables in the current
          database, are to transaction ID wraparound. If a database reaches
          about 2 billion transactions without its old rows being frozen,
          PostgreSQL stops accepting writes to protect the data. Autovacuum
          normally prevents this; this script checks that it is keeping up.
Usage   : Run as is. pct_to_wraparound above about 50% deserves a look; above
          75% needs action (find what blocks vacuum: long transactions,
          abandoned replication slots, old prepared transactions).
Changes : Read-only.
Requires: PostgreSQL 13 and later.
*/

-- 1. Every database
SELECT  datname                                                          AS database_name,
        age(datfrozenxid)                                                AS xid_age,
        current_setting('autovacuum_freeze_max_age')::bigint             AS autovacuum_freeze_max_age,
        round(100.0 * age(datfrozenxid) / 2147483648, 1)                 AS pct_to_wraparound
FROM pg_database
ORDER BY xid_age DESC;

-- 2. Oldest tables in the current database
SELECT  c.oid::regclass                                                  AS table_name,
        age(c.relfrozenxid)                                              AS xid_age,
        pg_size_pretty(pg_total_relation_size(c.oid))                    AS total_size
FROM pg_class AS c
WHERE c.relkind IN ('r', 'm', 't')
ORDER BY age(c.relfrozenxid) DESC
LIMIT 20;

-- 3. Things that stop vacuum freezing rows
SELECT 'oldest open transaction' AS what, max(now() - xact_start)::text AS detail
FROM pg_stat_activity WHERE xact_start IS NOT NULL
UNION ALL
SELECT 'prepared transactions', count(*)::text FROM pg_prepared_xacts
UNION ALL
SELECT 'inactive replication slots', count(*)::text FROM pg_replication_slots WHERE NOT active;
