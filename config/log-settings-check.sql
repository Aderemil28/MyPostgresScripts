/*
Script  : log-settings-check.sql
Purpose : Compares the server's logging settings with the recommendations in
          cheatsheets/log-management-parameters.md, shows the current log
          file, and lists log files with their sizes.
Usage   : Run as is. OK = matches the recommendation, REVIEW = differs (the
          cheat sheet explains when a different value is right).
          Section 3 needs pg_monitor or superuser and returns no rows when
          logging_collector is off. On AlloyDB / Cloud SQL, parameters 1 to 8
          are managed by the service, so only the rest apply.
Changes : Read-only. The commented block at the end applies the
          recommendations with ALTER SYSTEM.
Requires: PostgreSQL 13 and later.
*/

-- 1. Current value against the recommendation
WITH recommended(sort_order, name, recommended) AS (
    VALUES
        (1,  'logging_collector',           'on'),
        (2,  'log_destination',             'stderr'),
        (3,  'log_directory',               'log'),
        (4,  'log_filename',                'postgresql-%a.log'),
        (5,  'log_rotation_age',            '1440'),     -- minutes = 1d
        (6,  'log_rotation_size',           '0'),
        (7,  'log_truncate_on_rotation',    'on'),
        (8,  'log_line_prefix',             '%m [%p] %quser=%u db=%d app=%a client=%h '),
        (9,  'log_min_duration_statement',  '1000'),
        (10, 'log_statement',               'ddl'),
        (11, 'log_lock_waits',              'on'),
        (12, 'log_checkpoints',             'on'),
        (13, 'log_connections',             'on'),
        (14, 'log_disconnections',          'on'),
        (15, 'log_autovacuum_min_duration', '10000'),    -- ms = 10s
        (16, 'log_temp_files',              '10240')     -- kB = 10MB
)
SELECT  r.sort_order                                   AS "#",
        s.name,
        s.setting                                      AS current_value,
        s.unit,
        r.recommended,
        CASE WHEN s.setting = r.recommended THEN 'OK' ELSE 'REVIEW' END AS status,
        s.source,
        CASE WHEN s.context = 'postmaster' THEN 'restart' ELSE 'reload' END AS change_needs,
        s.pending_restart
FROM recommended AS r
JOIN pg_settings AS s ON s.name = r.name
ORDER BY r.sort_order;

-- 2. The file being written now (NULL when logging_collector is off)
SELECT pg_current_logfile() AS current_log_file,
       current_setting('data_directory', true) AS data_directory;

-- 3. Log files and their sizes, newest first. The directory is only read
--    while a log file is being written: with logging_collector off the
--    folder may not exist, and this returns no rows instead of an error.
--    (MATERIALIZED and OFFSET 0 stop the planner reading it anyway.)
WITH g AS MATERIALIZED (SELECT 1 AS x WHERE pg_current_logfile() IS NOT NULL)
SELECT l.name, pg_size_pretty(l.size) AS size, l.modification
FROM g
CROSS JOIN LATERAL (SELECT * FROM pg_ls_logdir() WHERE g.x = 1 OFFSET 0) AS l
ORDER BY l.modification DESC;

-- 4. Apply the recommendations (superuser). Review first, then uncomment.
--    logging_collector needs a restart; everything else takes effect on reload.
-- ALTER SYSTEM SET logging_collector = 'on';
-- ALTER SYSTEM SET log_destination = 'stderr';
-- ALTER SYSTEM SET log_directory = 'log';
-- ALTER SYSTEM SET log_filename = 'postgresql-%a.log';
-- ALTER SYSTEM SET log_rotation_age = '1d';
-- ALTER SYSTEM SET log_rotation_size = '0';
-- ALTER SYSTEM SET log_truncate_on_rotation = 'on';
-- ALTER SYSTEM SET log_line_prefix = '%m [%p] %quser=%u db=%d app=%a client=%h ';
-- ALTER SYSTEM SET log_min_duration_statement = '1000';
-- ALTER SYSTEM SET log_statement = 'ddl';
-- ALTER SYSTEM SET log_lock_waits = 'on';
-- ALTER SYSTEM SET log_checkpoints = 'on';
-- ALTER SYSTEM SET log_connections = 'on';
-- ALTER SYSTEM SET log_disconnections = 'on';
-- ALTER SYSTEM SET log_autovacuum_min_duration = '10s';
-- ALTER SYSTEM SET log_temp_files = '10MB';
-- SELECT pg_reload_conf();
