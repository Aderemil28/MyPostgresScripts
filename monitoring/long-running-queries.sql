/*
Script  : long-running-queries.sql
Purpose : Queries running longer than a threshold, and sessions sitting
          "idle in transaction" (open transactions that hold locks and stop
          vacuum from cleaning up).
Usage   : Change the threshold in the params CTE (default 5 minutes).
Changes : Read-only.
Requires: PostgreSQL 13 and later. pg_read_all_stats (or pg_monitor) to see
          other users' query text.
*/

-- 1. Active queries over the threshold
WITH params AS (SELECT interval '5 minutes' AS threshold)
SELECT  a.pid,
        a.usename                    AS user_name,
        a.datname                    AS database_name,
        a.application_name,
        now() - a.query_start        AS query_runtime,
        a.wait_event_type,
        a.wait_event,
        left(a.query, 300)           AS query_text
FROM pg_stat_activity AS a, params AS p
WHERE a.backend_type = 'client backend'
  AND a.state = 'active'
  AND now() - a.query_start > p.threshold
  AND a.pid <> pg_backend_pid()
ORDER BY query_runtime DESC;

-- 2. Open transactions doing nothing
WITH params AS (SELECT interval '5 minutes' AS threshold)
SELECT  a.pid,
        a.usename                    AS user_name,
        a.datname                    AS database_name,
        a.application_name,
        a.client_addr,
        now() - a.xact_start         AS transaction_age,
        now() - a.state_change       AS idle_for,
        left(a.query, 300)           AS last_query
FROM pg_stat_activity AS a, params AS p
WHERE a.state IN ('idle in transaction', 'idle in transaction (aborted)')
  AND now() - a.state_change > p.threshold
ORDER BY transaction_age DESC;

-- Prevention: set idle_in_transaction_session_timeout for the application role,
-- for example ALTER ROLE app_user SET idle_in_transaction_session_timeout = '15min';
