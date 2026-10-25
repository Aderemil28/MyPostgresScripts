/*
Script  : privileges-report.sql
Purpose : Who can do what in the current database: database-level privileges,
          schema privileges, table privileges (one row per grantee and
          table), and default privileges that will apply to future tables.
          Useful for access reviews and audit requests.
Usage   : Connect to the database you want, then run.
Changes : Read-only.
Requires: PostgreSQL 13 and later.
*/

-- 1. Database privileges (CONNECT, CREATE, TEMPORARY)
SELECT  d.datname                                   AS database_name,
        coalesce(g.rolname, 'PUBLIC')               AS grantee,
        a.privilege_type
FROM pg_database AS d
CROSS JOIN LATERAL aclexplode(d.datacl) AS a
LEFT JOIN pg_roles AS g ON g.oid = a.grantee
WHERE d.datname = current_database()
ORDER BY grantee, a.privilege_type;

-- 2. Schema privileges (USAGE, CREATE)
SELECT  n.nspname                                   AS schema_name,
        pg_get_userbyid(n.nspowner)                 AS schema_owner,
        coalesce(g.rolname, 'PUBLIC')               AS grantee,
        a.privilege_type
FROM pg_namespace AS n
CROSS JOIN LATERAL aclexplode(n.nspacl) AS a
LEFT JOIN pg_roles AS g ON g.oid = a.grantee
WHERE n.nspname NOT IN ('pg_catalog', 'information_schema')
  AND n.nspname NOT LIKE 'pg_toast%'
ORDER BY schema_name, grantee, a.privilege_type;

-- 3. Table and view privileges, one row per grantee and table
SELECT  table_schema,
        table_name,
        grantee,
        string_agg(privilege_type, ', ' ORDER BY privilege_type) AS privileges
FROM information_schema.role_table_grants
WHERE table_schema NOT IN ('pg_catalog', 'information_schema')
GROUP BY table_schema, table_name, grantee
ORDER BY table_schema, table_name, grantee;

-- 4. Default privileges (what new objects will grant automatically)
SELECT  pg_get_userbyid(d.defaclrole)               AS for_objects_created_by,
        coalesce(n.nspname, '(all schemas)')        AS schema_name,
        CASE d.defaclobjtype WHEN 'r' THEN 'tables' WHEN 'S' THEN 'sequences'
             WHEN 'f' THEN 'functions' WHEN 'T' THEN 'types' WHEN 'n' THEN 'schemas'
             END                                    AS object_type,
        coalesce(g.rolname, 'PUBLIC')               AS grantee,
        a.privilege_type
FROM pg_default_acl AS d
LEFT JOIN pg_namespace AS n ON n.oid = d.defaclnamespace
CROSS JOIN LATERAL aclexplode(d.defaclacl) AS a
LEFT JOIN pg_roles AS g ON g.oid = a.grantee
ORDER BY for_objects_created_by, schema_name, object_type, grantee;
