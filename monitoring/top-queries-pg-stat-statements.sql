/*
Script  : top-queries-pg-stat-statements.sql
Purpose : The 20 queries using the most total execution time since the
          statistics were last reset, with calls, mean time, rows and buffer
          reads. The closest thing to Query Store / sys.dm_exec_query_stats.
Usage   : pg_stat_statements must be in shared_preload_libraries (a restart is
          needed to add it) and the extension created in the database you
          connect to:
              CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
          On AlloyDB and Cloud SQL, pg_stat_statements is available; create
          the extension the same way.
          Change ORDER BY to mean_exec_time or shared_blks_read for other views.
Changes : Read-only. (Reset with SELECT pg_stat_statements_reset(); only when you
          mean to start a fresh measurement.)
Requires: PostgreSQL 13 and later (total_exec_time / mean_exec_time columns).
*/
SELECT  d.datname                                                   AS database_name,
        r.rolname                                                   AS user_name,
        s.calls,
        round(s.total_exec_time::numeric, 0)                        AS total_ms,
        round(s.mean_exec_time::numeric, 2)                         AS mean_ms,
        round((100 * s.total_exec_time
               / nullif(sum(s.total_exec_time) OVER (), 0))::numeric, 1) AS pct_of_total,
        s.rows,
        s.shared_blks_hit,
        s.shared_blks_read,
        left(regexp_replace(s.query, '\s+', ' ', 'g'), 200)         AS query_text
FROM pg_stat_statements AS s
JOIN pg_database AS d ON d.oid = s.dbid
JOIN pg_roles    AS r ON r.oid = s.userid
ORDER BY s.total_exec_time DESC
LIMIT 20;

-- When were the statistics last reset? (PostgreSQL 14 and later)
-- SELECT stats_reset FROM pg_stat_statements_info;
