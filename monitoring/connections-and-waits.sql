/*
Script  : connections-and-waits.sql
Purpose : How close the server is to max_connections, who holds the
          connections, and what active sessions are waiting on right now.
Usage   : Run as is. Re-run a few times: waits are a point-in-time snapshot.
Changes : Read-only.
Requires: PostgreSQL 13 and later.
*/

-- 1. Connections used against max_connections
SELECT  count(*)                                          AS client_connections,
        current_setting('max_connections')::int           AS max_connections,
        current_setting('superuser_reserved_connections')::int AS reserved_for_superuser,
        round(100.0 * count(*) / current_setting('max_connections')::int, 1) AS pct_used
FROM pg_stat_activity
WHERE backend_type = 'client backend';

-- 2. Who holds them
SELECT  datname          AS database_name,
        usename          AS user_name,
        application_name,
        client_addr,
        state,
        count(*)         AS connections
FROM pg_stat_activity
WHERE backend_type = 'client backend'
GROUP BY datname, usename, application_name, client_addr, state
ORDER BY connections DESC;

-- 3. What active sessions are waiting on (NULL wait = running on CPU)
SELECT  coalesce(wait_event_type, 'CPU / not waiting') AS wait_event_type,
        wait_event,
        count(*)                                       AS sessions
FROM pg_stat_activity
WHERE backend_type = 'client backend'
  AND state = 'active'
  AND pid <> pg_backend_pid()
GROUP BY wait_event_type, wait_event
ORDER BY sessions DESC;
