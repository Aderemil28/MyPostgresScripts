/*
Script  : database-sizes.sql
Purpose : Size of every database on the server, largest first, plus the total.
Usage   : Run as is from any database.
Changes : Read-only.
Requires: PostgreSQL 13 and later. CONNECT privilege on a database to see its
          size (superusers and pg_read_all_stats members see all).
*/
SELECT  d.datname                                 AS database_name,
        pg_get_userbyid(d.datdba)                 AS owner_name,
        pg_size_pretty(pg_database_size(d.datname)) AS size,
        pg_database_size(d.datname)               AS size_bytes,
        d.datconnlimit                            AS connection_limit
FROM pg_database AS d
WHERE d.datallowconn
  AND has_database_privilege(d.datname, 'CONNECT')
ORDER BY size_bytes DESC;

SELECT pg_size_pretty(sum(pg_database_size(datname))) AS total_size
FROM pg_database
WHERE datallowconn
  AND has_database_privilege(datname, 'CONNECT');
