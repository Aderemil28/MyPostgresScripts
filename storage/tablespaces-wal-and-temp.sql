/*
Script  : tablespaces-wal-and-temp.sql
Purpose : Where the space goes outside the tables themselves: tablespace sizes
          and locations, the size of the WAL directory, and temp files written
          per database.
Usage   : Run as is. Section 2 needs pg_monitor (or superuser); on managed
          services such as AlloyDB and Cloud SQL it may not be allowed, so
          use the service's storage metrics instead.
Changes : Read-only.
Requires: PostgreSQL 13 and later.
*/

-- 1. Tablespaces (an empty location means the default data directory)
SELECT  spcname                                       AS tablespace_name,
        pg_get_userbyid(spcowner)                     AS owner_name,
        pg_tablespace_location(oid)                   AS location,
        pg_size_pretty(pg_tablespace_size(oid))       AS size
FROM pg_tablespace
ORDER BY pg_tablespace_size(oid) DESC;

-- 2. WAL directory. A large or growing WAL usually means an inactive
--    replication slot or failing WAL archiving (see replication/replication-slots.sql).
SELECT  count(*)                                      AS wal_files,
        pg_size_pretty(sum(size))                     AS wal_size
FROM pg_ls_waldir();

-- 3. Temp files written since the last stats reset (sorts and hashes spilling
--    to disk). High values point at work_mem or a query that needs tuning.
SELECT  datname                                       AS database_name,
        temp_files,
        pg_size_pretty(temp_bytes)                    AS temp_written,
        stats_reset
FROM pg_stat_database
WHERE datname IS NOT NULL AND temp_files > 0
ORDER BY temp_bytes DESC;
