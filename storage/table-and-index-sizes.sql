/*
Script  : table-and-index-sizes.sql
Purpose : The 30 largest tables in the current database with total size, table
          (heap) size, index size, TOAST size and estimated rows. Then the 30
          largest indexes.
Usage   : Connect to the database you want, then run.
Changes : Read-only.
Requires: PostgreSQL 13 and later.
Notes   : Row counts are the planner's estimate (reltuples) from the last
          ANALYZE, not a COUNT(*). -1 means the table has never been analyzed.
*/

-- 1. Largest tables
SELECT  n.nspname                                         AS schema_name,
        c.relname                                         AS table_name,
        pg_size_pretty(pg_total_relation_size(c.oid))     AS total_size,
        pg_size_pretty(pg_relation_size(c.oid))           AS table_size,
        pg_size_pretty(pg_indexes_size(c.oid))            AS index_size,
        pg_size_pretty(coalesce(pg_total_relation_size(nullif(c.reltoastrelid, 0)), 0)) AS toast_size,
        c.reltuples::bigint                               AS estimated_rows
FROM pg_class AS c
JOIN pg_namespace AS n ON n.oid = c.relnamespace
WHERE c.relkind IN ('r', 'p', 'm')
  AND n.nspname NOT IN ('pg_catalog', 'information_schema')
  AND n.nspname NOT LIKE 'pg_toast%'
ORDER BY pg_total_relation_size(c.oid) DESC
LIMIT 30;

-- 2. Largest indexes
SELECT  n.nspname                                         AS schema_name,
        t.relname                                         AS table_name,
        i.relname                                         AS index_name,
        pg_size_pretty(pg_relation_size(i.oid))           AS index_size
FROM pg_index AS x
JOIN pg_class AS i ON i.oid = x.indexrelid
JOIN pg_class AS t ON t.oid = x.indrelid
JOIN pg_namespace AS n ON n.oid = t.relnamespace
WHERE n.nspname NOT IN ('pg_catalog', 'information_schema')
  AND n.nspname NOT LIKE 'pg_toast%'
ORDER BY pg_relation_size(i.oid) DESC
LIMIT 30;
