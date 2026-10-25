/*
Script  : settings-review.sql
Purpose : What has been changed from the defaults and where it was set, any
          setting waiting for a restart, errors in the configuration files,
          and the settings most worth reviewing on a new server.
Usage   : Run as is. Section 3 needs superuser (or on managed services, is
          not available: AlloyDB and Cloud SQL set these through database flags).
          Change a setting with ALTER SYSTEM SET name = 'value'; then
          SELECT pg_reload_conf(); or restart, depending on the setting's context.
Changes : Read-only.
Requires: PostgreSQL 13 and later.
*/

-- 1. Settings changed from the default, and where
SELECT  name, setting, unit, source, sourcefile, sourceline, context
FROM pg_settings
WHERE source NOT IN ('default', 'override', 'client', 'session')
ORDER BY name;

-- 2. Changed but not live until a restart
SELECT name, setting, unit
FROM pg_settings
WHERE pending_restart;

-- 3. Errors in postgresql.conf / postgresql.auto.conf
SELECT sourcefile, sourceline, name, setting, error
FROM pg_file_settings
WHERE error IS NOT NULL;

-- 4. The usual review list
SELECT  name, setting, unit, context, short_desc
FROM pg_settings
WHERE name IN ('max_connections', 'shared_buffers', 'effective_cache_size', 'work_mem',
               'maintenance_work_mem', 'max_wal_size', 'min_wal_size', 'checkpoint_timeout',
               'checkpoint_completion_target', 'random_page_cost', 'effective_io_concurrency',
               'wal_level', 'max_wal_senders', 'max_replication_slots', 'archive_mode',
               'log_min_duration_statement', 'log_lock_waits', 'log_checkpoints',
               'idle_in_transaction_session_timeout', 'statement_timeout',
               'shared_preload_libraries', 'track_io_timing')
ORDER BY name;
