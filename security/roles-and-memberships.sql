/*
Script  : roles-and-memberships.sql
Purpose : Every role with its attributes (login, superuser, create role,
          create database, replication, bypass row-level security), password
          expiry, connection limit, and the roles it is a member of.
          In Postgres, logins, users and groups are all roles.
Usage   : Run as is. Built-in pg_ roles are hidden.
Changes : Read-only.
Requires: PostgreSQL 13 and later.
*/
SELECT  r.rolname                                   AS role_name,
        r.rolcanlogin                               AS can_login,
        r.rolsuper                                  AS is_superuser,
        r.rolcreaterole                             AS can_create_role,
        r.rolcreatedb                               AS can_create_db,
        r.rolreplication                            AS can_replicate,
        r.rolbypassrls                              AS bypasses_rls,
        r.rolconnlimit                              AS connection_limit,
        r.rolvaliduntil                             AS password_expires,
        ARRAY(SELECT g.rolname
              FROM pg_auth_members AS m
              JOIN pg_roles AS g ON g.oid = m.roleid
              WHERE m.member = r.oid
              ORDER BY g.rolname)                   AS member_of
FROM pg_roles AS r
WHERE r.rolname !~ '^pg_'
ORDER BY r.rolcanlogin DESC, r.rolname;
