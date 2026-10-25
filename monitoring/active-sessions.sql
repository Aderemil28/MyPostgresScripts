/*
Script  : active-sessions.sql
Purpose : Every client session that is doing something: state, wait event, who
          is blocking it, how long the query and the transaction have been
          running, and the query text. The Postgres answer to sp_who2 and
          sys.dm_exec_requests.
Usage   : psql -f active-sessions.sql, or paste into any client.
          Idle sessions are hidden. Remove the state filter to see them too.
Changes : Read-only.
Requires: PostgreSQL 13 and later. Membership of pg_read_all_stats (or
          pg_monitor) to see other users' query text.
*/
SELECT  a.pid,
        a.usename                       AS user_name,
        a.datname                       AS database_name,
        a.application_name,
        a.client_addr,
        a.state,
        a.wait_event_type,
        a.wait_event,
        pg_blocking_pids(a.pid)         AS blocked_by,
        now() - a.query_start           AS query_runtime,
        now() - a.xact_start            AS transaction_age,
        left(a.query, 200)              AS query_text
FROM pg_stat_activity AS a
WHERE a.backend_type = 'client backend'
  AND a.state <> 'idle'
  AND a.pid <> pg_backend_pid()
ORDER BY a.xact_start NULLS LAST;
