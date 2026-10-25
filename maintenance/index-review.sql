/*
Script  : index-review.sql
Purpose : Three index checks for the current database:
            1. Unused indexes (never scanned since stats were reset) that are
               not backing a primary key or unique constraint
            2. Duplicate indexes (same table, same columns, same options)
            3. Foreign keys with no index on the referencing columns, which
               makes deletes and updates on the parent table slow and causes
               lock waits
Usage   : Connect to the database you want, then run. Check stats_reset first:
          an index used only at month end looks unused if stats were reset
          last week. On a replica setup, check every server before dropping:
          index usage is tracked per server.
Changes : Read-only. Drop with DROP INDEX CONCURRENTLY to avoid blocking.
Requires: PostgreSQL 13 and later.
*/

-- When were the usage statistics last reset?
SELECT datname, stats_reset FROM pg_stat_database WHERE datname = current_database();

-- 1. Unused indexes, largest first
SELECT  s.schemaname,
        s.relname                                       AS table_name,
        s.indexrelname                                  AS index_name,
        pg_size_pretty(pg_relation_size(s.indexrelid))  AS index_size,
        s.idx_scan
FROM pg_stat_user_indexes AS s
JOIN pg_index AS i ON i.indexrelid = s.indexrelid
WHERE s.idx_scan = 0
  AND NOT i.indisunique
  AND NOT i.indisprimary
ORDER BY pg_relation_size(s.indexrelid) DESC;

-- 2. Duplicate indexes (keep one of each group)
SELECT  pg_size_pretty(sum(pg_relation_size(idx))::bigint) AS total_size,
        string_agg(idx::text, ', ')                        AS duplicate_indexes
FROM (
    SELECT  indexrelid::regclass AS idx,
            indrelid::text || ' ' || indclass::text || ' ' || indkey::text || ' '
            || coalesce(indexprs::text, '') || ' ' || coalesce(indpred::text, '') AS index_key
    FROM pg_index
) AS x
GROUP BY index_key
HAVING count(*) > 1
ORDER BY sum(pg_relation_size(idx)) DESC;

-- 3. Foreign keys without a supporting index (leading columns must match)
SELECT  c.conrelid::regclass                AS table_name,
        c.conname                           AS foreign_key,
        pg_get_constraintdef(c.oid)         AS definition
FROM pg_constraint AS c
WHERE c.contype = 'f'
  AND NOT EXISTS (
        SELECT 1
        FROM pg_index AS i
        WHERE i.indrelid = c.conrelid
          AND (string_to_array(i.indkey::text, ' ')::int2[])[1:cardinality(c.conkey)] @> c.conkey
          AND (string_to_array(i.indkey::text, ' ')::int2[])[1:cardinality(c.conkey)] <@ c.conkey
      )
ORDER BY c.conrelid::regclass::text, c.conname;
