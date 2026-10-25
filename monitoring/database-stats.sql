/*
Script  : database-stats.sql
Purpose : Per-database health counters since the last stats reset: cache hit
          ratio, commits and rollbacks, deadlocks, temp file usage and
          conflicts (on standbys). Then the tables with the lowest cache hit
          ratio in the current database.
Usage   : Run as is. A cache hit ratio well below 99% on a busy OLTP database
          usually means shared_buffers or memory is too small for the working set.
Changes : Read-only.
Requires: PostgreSQL 13 and later.
*/

-- 1. Every database
SELECT  datname                                                     AS database_name,
        numbackends                                                 AS connections,
        xact_commit,
        xact_rollback,
        round(100.0 * blks_hit / nullif(blks_hit + blks_read, 0), 2) AS cache_hit_pct,
        deadlocks,
        temp_files,
        pg_size_pretty(temp_bytes)                                  AS temp_written,
        conflicts,
        stats_reset
FROM pg_stat_database
WHERE datname IS NOT NULL
ORDER BY xact_commit + xact_rollback DESC;

-- 2. Tables in the current database read from disk the most
SELECT  schemaname,
        relname                                                                AS table_name,
        heap_blks_read,
        heap_blks_hit,
        round(100.0 * heap_blks_hit / nullif(heap_blks_hit + heap_blks_read, 0), 2) AS heap_hit_pct,
        idx_blks_read,
        idx_blks_hit
FROM pg_statio_user_tables
ORDER BY heap_blks_read DESC
LIMIT 20;
