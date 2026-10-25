/*
Script  : terminate-sessions-for-database.sql
Purpose : Disconnect everyone from one database, for example before a restore,
          a rename or a drop. Lists the sessions first.
Usage   : Replace appdb with the database name. Run section 1, check the list
          with the application owner, then uncomment and run section 2.
          Connect to a different database (for example postgres) to run it.
          To stop new connections arriving while you work:
              ALTER DATABASE appdb WITH ALLOW_CONNECTIONS false;
          and set it back to true afterwards.
          PostgreSQL 13 and later can also do it in one step when dropping:
              DROP DATABASE appdb WITH (FORCE);
Changes : Section 2 ends sessions; their open transactions roll back.
Requires: PostgreSQL 13 and later. Superuser, or membership of
          pg_signal_backend (which cannot end superuser sessions).
*/

-- 1. Who is connected
SELECT pid, usename AS user_name, application_name, client_addr, state,
       now() - backend_start AS connected_for
FROM pg_stat_activity
WHERE datname = 'appdb'
  AND pid <> pg_backend_pid();

-- 2. End them
-- SELECT pid, pg_terminate_backend(pid) AS terminated
-- FROM pg_stat_activity
-- WHERE datname = 'appdb'
--   AND pid <> pg_backend_pid();
