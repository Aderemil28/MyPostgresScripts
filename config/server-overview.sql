/*
Script  : server-overview.sql
Purpose : First thing to run on an unfamiliar server: version, uptime,
          primary or standby, data directory, key memory settings, databases,
          and the extensions installed in the current database (with any
          that have an update available).
Usage   : Run as is. data_directory needs superuser or pg_read_all_settings,
          and shows NULL otherwise.
Changes : Read-only.
Requires: PostgreSQL 13 and later.
*/

-- 1. The server
SELECT  version()                                         AS version,
        current_setting('server_version_num')::int        AS version_num,
        pg_postmaster_start_time()                        AS started_at,
        now() - pg_postmaster_start_time()                AS uptime,
        pg_is_in_recovery()                               AS is_standby,
        current_setting('data_directory', true)           AS data_directory,
        current_setting('max_connections')                AS max_connections,
        current_setting('shared_buffers')                 AS shared_buffers,
        current_setting('effective_cache_size')           AS effective_cache_size,
        current_setting('work_mem')                       AS work_mem,
        current_setting('maintenance_work_mem')           AS maintenance_work_mem;

-- 2. Databases
SELECT  datname                                           AS database_name,
        pg_get_userbyid(datdba)                           AS owner_name,
        pg_encoding_to_char(encoding)                     AS encoding,
        datcollate                                        AS collation,
        datallowconn                                      AS allows_connections
FROM pg_database
ORDER BY datname;

-- 3. Extensions in this database
SELECT  e.extname                                         AS extension,
        e.extversion                                      AS installed_version,
        a.default_version                                 AS available_version,
        e.extversion <> a.default_version                 AS update_available
FROM pg_extension AS e
JOIN pg_available_extensions AS a ON a.name = e.extname
ORDER BY e.extname;
