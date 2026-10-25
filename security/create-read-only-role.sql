/*
Script  : create-read-only-role.sql
Purpose : Template for least-privilege read-only access to one schema: a
          group role that holds the privileges, a login role that is a
          member of it, and default privileges so tables created later are
          readable too (the step most often missed).
Usage   : Find and replace before running:
              appdb         database
              app           schema
              app_owner     role that owns (creates) the tables in the schema
              app_readonly  group role to create
              report_user   login to create
          Run as a role allowed to create roles (superuser, CREATEROLE, or on
          AlloyDB / Cloud SQL the service's admin user), connected to appdb.
          Set the password with \password report_user in psql rather than
          writing it in the script.
          PostgreSQL 14 and later also have the built-in pg_read_all_data role,
          but that covers every schema in every database: too broad for most
          requests.
Changes : Creates two roles and grants privileges.
Requires: PostgreSQL 13 and later.
*/

-- 1. Group role that holds the privileges (cannot log in)
CREATE ROLE app_readonly NOLOGIN;

GRANT CONNECT ON DATABASE appdb TO app_readonly;
GRANT USAGE ON SCHEMA app TO app_readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA app TO app_readonly;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA app TO app_readonly;

-- 2. Future tables created by app_owner in schema app
ALTER DEFAULT PRIVILEGES FOR ROLE app_owner IN SCHEMA app
    GRANT SELECT ON TABLES TO app_readonly;
ALTER DEFAULT PRIVILEGES FOR ROLE app_owner IN SCHEMA app
    GRANT SELECT ON SEQUENCES TO app_readonly;

-- 3. The login. Set its password afterwards with \password report_user
CREATE ROLE report_user LOGIN IN ROLE app_readonly;

-- Optional: limit connections and stop runaway queries for this login
ALTER ROLE report_user CONNECTION LIMIT 10;
ALTER ROLE report_user SET statement_timeout = '15min';

-- 4. Check: should be true, true, false
SELECT  has_table_privilege('report_user', t.oid, 'SELECT') AS can_select,
        has_schema_privilege('report_user', 'app', 'USAGE')  AS can_use_schema,
        has_table_privilege('report_user', t.oid, 'INSERT') AS can_insert
FROM pg_class AS t
JOIN pg_namespace AS n ON n.oid = t.relnamespace
WHERE n.nspname = 'app' AND t.relkind = 'r'
LIMIT 1;
