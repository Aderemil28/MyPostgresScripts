/*
Script  : authentication-review.sql
Purpose : Security review of how clients get in: superuser roles, login roles
          with no password expiry, the password hashing method in use, which
          sessions are encrypted with SSL, and the pg_hba.conf rules.
Usage   : Run as is. Sections 3 and 5 need superuser. On AlloyDB and Cloud SQL
          there is no true superuser and pg_hba.conf is managed by the
          service, so skip those sections there.
Changes : Read-only.
Requires: PostgreSQL 13 and later.
*/

-- 1. Superusers (should be a very short list)
SELECT rolname AS superuser, rolcanlogin AS can_login
FROM pg_roles
WHERE rolsuper
ORDER BY rolname;

-- 2. Login roles with no password expiry
SELECT rolname AS login_role, rolvaliduntil AS password_expires
FROM pg_roles
WHERE rolcanlogin AND rolname !~ '^pg_'
  AND (rolvaliduntil IS NULL OR rolvaliduntil = 'infinity')
ORDER BY rolname;

-- 3. Password hash method per login (scram-sha-256 is current; md5 is
--    deprecated). Needs superuser because it reads pg_authid.
SELECT  rolname AS login_role,
        CASE WHEN rolpassword IS NULL              THEN 'no password (other auth method)'
             WHEN rolpassword LIKE 'SCRAM-SHA-256$%' THEN 'scram-sha-256'
             WHEN rolpassword LIKE 'md5%'            THEN 'md5 (reset the password to upgrade)'
             ELSE 'other' END                AS password_hash
FROM pg_authid
WHERE rolcanlogin
ORDER BY rolname;

-- 4. Server settings, and which current sessions use SSL
SELECT name, setting
FROM pg_settings
WHERE name IN ('password_encryption', 'ssl', 'ssl_min_protocol_version', 'listen_addresses');

SELECT  a.usename                AS user_name,
        a.client_addr,
        a.application_name,
        coalesce(s.ssl, false)   AS ssl,
        s.version                AS tls_version
FROM pg_stat_activity AS a
LEFT JOIN pg_stat_ssl AS s ON s.pid = a.pid
WHERE a.backend_type = 'client backend'
ORDER BY ssl, user_name;

-- 5. pg_hba.conf rules as the server reads them (needs superuser).
--    Look for 'trust', 'password' (plain text) and wide-open addresses.
SELECT line_number, type, database, user_name, address, netmask, auth_method, error
FROM pg_hba_file_rules
ORDER BY line_number;
