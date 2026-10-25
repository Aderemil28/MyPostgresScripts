/*
Script  : vacuum-and-analyze-status.sql
Purpose : Dead rows, when each table was last vacuumed and analyzed (manually
          or by autovacuum), and any vacuum running right now with its progress.
          Vacuum is the Postgres housekeeping SQL Server doesn't have: it
          reclaims space from updated and deleted rows (MVCC) and keeps the
          planner's statistics fresh.
Usage   : Connect to the database you want, then run.
Changes : Read-only. To vacuum a table by hand: VACUUM (VERBOSE, ANALYZE) schema.table;
Requires: PostgreSQL 13 and later.
*/

-- 1. Tables with the most dead rows
SELECT  schemaname,
        relname                                                         AS table_name,
        n_live_tup                                                      AS live_rows,
        n_dead_tup                                                      AS dead_rows,
        round(100.0 * n_dead_tup / nullif(n_live_tup + n_dead_tup, 0), 1) AS dead_pct,
        last_vacuum,
        last_autovacuum,
        last_analyze,
        last_autoanalyze,
        autovacuum_count,
        autoanalyze_count
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC
LIMIT 30;

-- 2. Vacuums running now
SELECT  p.pid,
        p.datname                                                       AS database_name,
        p.relid::regclass                                               AS table_name,
        p.phase,
        round(100.0 * p.heap_blks_scanned / nullif(p.heap_blks_total, 0), 1) AS pct_scanned,
        p.index_vacuum_count,
        now() - a.xact_start                                            AS running_for,
        left(a.query, 100)                                              AS command
FROM pg_stat_progress_vacuum AS p
JOIN pg_stat_activity AS a ON a.pid = p.pid;

-- 3. Autovacuum settings in force
SELECT name, setting, unit
FROM pg_settings
WHERE name LIKE 'autovacuum%'
ORDER BY name;
