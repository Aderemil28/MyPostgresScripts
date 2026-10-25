/*
Script  : blocking-locks.sql
Purpose : Who is blocked, who is blocking them, and the session at the head of
          each blocking chain (the one to deal with).
Usage   : Run while the blocking is happening. To end a blocker, see the end
          of the script.
Changes : Read-only.
Requires: PostgreSQL 13 and later. pg_read_all_stats (or pg_monitor) to see
          other users' query text.
*/

-- 1. Every blocked session and the session(s) blocking it
SELECT  blocked.pid                          AS blocked_pid,
        blocked.usename                      AS blocked_user,
        now() - blocked.query_start          AS blocked_for,
        left(blocked.query, 150)             AS blocked_query,
        blocker.pid                          AS blocker_pid,
        blocker.usename                      AS blocker_user,
        blocker.state                        AS blocker_state,
        now() - blocker.xact_start           AS blocker_transaction_age,
        left(blocker.query, 150)             AS blocker_last_query
FROM pg_stat_activity AS blocked
CROSS JOIN LATERAL unnest(pg_blocking_pids(blocked.pid)) AS b(pid)
JOIN pg_stat_activity AS blocker ON blocker.pid = b.pid
ORDER BY blocked_for DESC;

-- 2. Head of each chain: blocking others but not blocked itself.
--    A state of 'idle in transaction' means the application opened a
--    transaction and never committed it.
SELECT  a.pid,
        a.usename                            AS user_name,
        a.application_name,
        a.client_addr,
        a.state,
        now() - a.xact_start                 AS transaction_age,
        left(a.query, 200)                   AS last_query
FROM pg_stat_activity AS a
WHERE a.pid IN (SELECT unnest(pg_blocking_pids(x.pid)) FROM pg_stat_activity AS x)
  AND cardinality(pg_blocking_pids(a.pid)) = 0;

-- To end a blocker (after agreeing it with the application owner):
--   SELECT pg_cancel_backend(<pid>);     -- cancels the running query only
--   SELECT pg_terminate_backend(<pid>);  -- ends the session, rolls back its transaction
