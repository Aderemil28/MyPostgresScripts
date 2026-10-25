# psql and SQL quick reference

The commands I type most inside psql, plus the short SQL one-liners that aren't worth a script of their own. Anything bigger has its own script in this repo: see [Where the rest lives](#where-the-rest-lives) at the end.

## Where each command runs

| Prompt | Meaning |
|---|---|
| `=#` | psql connected as a superuser (for example `postgres`) |
| `=>` | psql connected as a regular user |
| `$` / `>` | The OS shell: Linux bash (`$`), or Windows cmd / PowerShell (`>`). Not psql |

- **Backslash (`\`) commands work only in psql**, including the **PSQL Tool** in pgAdmin. The pgAdmin **Query Tool** runs SQL only and rejects them
- **SQL** ends with `;`. A backslash command doesn't need one
- Placeholders: database `appdb`, schema `app`, table `app.customer`, login `app_user`, owner role `app_owner`, server `db01`

## Connect

```bash
psql -h db01 -p 5432 -U app_user -d appdb
psql "host=db01 port=5432 dbname=appdb user=app_user sslmode=require"

# Run one command, or a file, and exit
psql -h db01 -U postgres -d appdb -c "SELECT version();"
psql -h db01 -U postgres -d appdb -v ON_ERROR_STOP=1 -f active-sessions.sql

# Tidy output for scripts: no psqlrc, unaligned, tuples only
psql -X -At -h db01 -U postgres -d postgres -c "SELECT datname FROM pg_database;"
```

Passwords go in a password file, never on the command line or in a script:

- Linux: `~/.pgpass`, then `chmod 600 ~/.pgpass`
- Windows: `%APPDATA%\postgresql\pgpass.conf` (create the folder if it isn't there)

```text
db01:5432:*:app_user:the_password
```

More shell commands (server control, backup, replication) are in [50 shell and CLI commands](50-postgres-cli-commands.md).

## The psql session

| Command | What it does |
|---|---|
| `\c appdb` | Connect to another database as the same user |
| `\c appdb app_user` | Connect to another database as another user (prompts for the password) |
| `\c "host=db01 dbname=appdb user=app_user sslmode=require"` | Reconnect with a full connection string. Leave the password out: psql prompts, or reads the password file |
| `\conninfo` | Who and where you are connected |
| `SELECT current_user, session_user, current_database(), inet_server_addr(), inet_server_port();` | The same as SQL, so it also works in pgAdmin's Query Tool. `current_user` changes after `SET ROLE`; `session_user` doesn't |
| `\! dir` / `\! ls` | Run an OS command without leaving psql (`\! cls` / `\! clear` clears the screen) |
| `\i C:/scripts/check.sql` | Run a file. On Windows use forward slashes |
| `\ir check.sql` | Run a file relative to the current script's folder (for scripts that call other scripts) |
| `\set ON_ERROR_STOP on` | Stop a script at the first error |
| `\timing on` | Show how long each statement takes |
| `\x auto` | Expanded output when rows are too wide for the screen |
| `\gx` | Re-run the last query once in expanded mode |
| `\watch 5` | Re-run the last query every 5 seconds (Ctrl+C to stop) |
| `\errverbose` | Full detail of the last error: SQLSTATE code, the server function that raised it, hints |
| `\pset null '(null)'` | Show NULL as `(null)` instead of blank, so you can tell NULL from an empty string |
| `\o out.txt` | Send output to a file (`\o` alone to stop) |
| `\copy app.customer TO 'customer.csv' CSV HEADER` | Export to a file on **your** machine (SQL `COPY` writes on the server) |
| `\e` | Edit the last query in your editor, then run it |
| `\s` | Command history |
| `\password app_user` | Set a password without it appearing in history or the server log. With no name it changes **your own** |
| `\q` | Quit |

## Finding things

Add `+` to most of these for sizes, owners and descriptions (`\dt+`, `\l+`, `\dn+`).

| Command | Lists |
|---|---|
| `\l` | Databases |
| `\dn` | Schemas |
| `\dt` / `\dt app.*` | Tables, all or in one schema |
| `\d app.customer` | Columns, indexes, constraints and triggers of one table (`\d+` adds size and storage) |
| `\dv app.*` / `\dm app.*` | Views / materialized views (without a pattern, only schemas on the search_path) |
| `\di app.*` | Indexes |
| `\ds` | Sequences |
| `\df app.*` | Functions and procedures |
| `\sf app.my_function` | The source code of a function |
| `\sv app.my_view` | The definition of a view |
| `\dx` | Installed extensions |
| `\du` | Roles and their attributes |
| `\drds` | Settings set per role or per database (`ALTER ROLE ... SET`) |
| `\dp app.*` | Privileges on tables, views and sequences |
| `\dconfig log*` | Server settings matching a pattern, non-default only (PostgreSQL 15 and later) |

## Server and session settings

```sql
SHOW config_file;        -- postgresql.conf
SHOW hba_file;           -- pg_hba.conf (who can connect, and how)
SHOW data_directory;     -- the instance's files
SHOW port;
SHOW cluster_name;       -- empty unless set; Debian/Ubuntu set it to e.g. 16/main
SHOW search_path;
SHOW ALL;                -- every setting (long)

-- Change a setting for this session only, then put it back
SET work_mem = '256MB';
SET statement_timeout = '5min';
RESET work_mem;
```

Server-wide changes (`ALTER SYSTEM`, reload, restart) are in [settings-review.sql](../config/settings-review.sql) and [log-management-parameters.md](log-management-parameters.md).

## Databases

```sql
CREATE DATABASE appdb OWNER app_owner ENCODING 'UTF8' TEMPLATE template0;

ALTER DATABASE appdb OWNER TO app_owner;
ALTER DATABASE appdb CONNECTION LIMIT 100;
ALTER DATABASE appdb SET statement_timeout = '5min';     -- default for every new session in appdb
ALTER DATABASE appdb RENAME TO appdb_old;                -- nobody can be connected to it

DROP DATABASE appdb_old WITH (FORCE);                    -- disconnects everyone first (PostgreSQL 13 and later)

-- Which folder under $PGDATA/base holds each database
SELECT oid AS folder, datname FROM pg_database ORDER BY datname;
```

## Schemas and search_path

`search_path` is the list of schemas PostgreSQL searches when a name isn't schema-qualified, like a default schema in SQL Server, but it can hold several.

```sql
CREATE SCHEMA app AUTHORIZATION app_owner;

SHOW search_path;                                        -- default: "$user", public
SET search_path TO app, public;                          -- this session only
ALTER ROLE app_user SET search_path TO app, public;      -- every new session for app_user
ALTER DATABASE appdb SET search_path TO app, public;     -- every new session in appdb

-- Stop everyone creating objects in public (already the default from PostgreSQL 15)
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
```

## Tables and storage

```sql
SELECT pg_relation_filepath('app.customer');             -- its file, relative to $PGDATA
SELECT pg_size_pretty(pg_total_relation_size('app.customer')) AS total,
       pg_size_pretty(pg_relation_size('app.customer'))       AS table_only;

-- Fast estimated row count (from the last ANALYZE) versus an exact count (reads the whole table)
SELECT reltuples::bigint AS estimated_rows FROM pg_class WHERE oid = 'app.customer'::regclass;
SELECT count(*) FROM app.customer;

ALTER TABLE app.customer OWNER TO app_owner;

-- DDL is transactional: you can try a change and roll it back
BEGIN;
ALTER TABLE app.customer ADD COLUMN phone text;
ROLLBACK;
```

## Users and permissions

Create the login, then set its password with `\password` so it never appears in history or the server log:

```sql
CREATE ROLE app_user LOGIN;
\password app_user
```

**Read-write access to one schema**, including tables created later. (For read-only, use [create-read-only-role.sql](../security/create-read-only-role.sql).)

```sql
GRANT CONNECT ON DATABASE appdb TO app_user;
GRANT USAGE ON SCHEMA app TO app_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA app TO app_user;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA app TO app_user;      -- needed for identity / serial columns

-- Tables and sequences that app_owner creates later
ALTER DEFAULT PRIVILEGES FOR ROLE app_owner IN SCHEMA app
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO app_user;
ALTER DEFAULT PRIVILEGES FOR ROLE app_owner IN SCHEMA app
    GRANT USAGE, SELECT ON SEQUENCES TO app_user;

-- Check
SELECT has_table_privilege('app_user', 'app.customer', 'INSERT') AS can_insert;
```

`ALTER DEFAULT PRIVILEGES FOR ROLE app_owner` covers only objects **app_owner** creates. If someone else creates a table, it isn't covered: create objects as the owner role.

**Lock, expire and unlock a login:**

```sql
ALTER ROLE app_user NOLOGIN;                             -- new logins refused; existing sessions keep running
SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE usename = 'app_user';   -- end them too
ALTER ROLE app_user LOGIN;
ALTER ROLE app_user VALID UNTIL '2026-12-31';            -- password stops working after this date
```

**Drop a user cleanly.** A role can't be dropped while it owns objects or holds privileges anywhere. Run the first two statements **in every database** where it has objects, then drop it:

```sql
REASSIGN OWNED BY app_user TO app_owner;                 -- hand its objects to another role
DROP OWNED BY app_user;                                  -- remove its remaining privileges
DROP ROLE app_user;                                      -- once, from any database
```

## Maintenance one-liners

```sql
VACUUM (ANALYZE, VERBOSE) app.customer;                  -- clean dead rows and refresh statistics
ANALYZE app.customer;                                    -- statistics only (fast)
REINDEX INDEX CONCURRENTLY app.customer_pkey;            -- rebuild without blocking writes (PostgreSQL 12 and later)

-- EXPLAIN ANALYZE really runs the statement. For INSERT, UPDATE or DELETE, wrap it so nothing changes:
BEGIN;
EXPLAIN (ANALYZE, BUFFERS) UPDATE app.customer SET name = name WHERE customer_id = 1;
ROLLBACK;
```

## On Windows

| Task | Command |
|---|---|
| Find psql if it isn't on the PATH | `"C:\Program Files\PostgreSQL\16\bin\psql.exe" -U postgres -d appdb` |
| Default data directory (EDB installer) | `C:\Program Files\PostgreSQL\16\data` |
| Service status / restart (PowerShell) | `Get-Service postgresql*` and `Restart-Service postgresql-x64-16` |
| Service restart (cmd, as administrator) | `net stop postgresql-x64-16` then `net start postgresql-x64-16` |
| Set the connection for this window (cmd) | `set PGHOST=db01` and `set PGUSER=app_user` |
| Same in PowerShell | `$env:PGHOST = "db01"; $env:PGUSER = "app_user"` |
| Show a variable from inside psql | `\! echo %PGHOST%` (cmd) |
| Password file | `%APPDATA%\postgresql\pgpass.conf` |
| psql startup file | `%APPDATA%\postgresql\psqlrc.conf` |
| *Console code page (437) differs from Windows code page (1252)* warning | Run `chcp 1252` before psql, or accented characters display wrongly |
| Run a script | `\i C:/scripts/check.sql` (forward slashes) |

Avoid `set PGPASSWORD=...` except for a quick test: it stays in the window's environment and in command history. Use the password file.

## Where the rest lives

These are covered by scripts in this repo, so they aren't repeated here:

| Task | Script |
|---|---|
| Version, uptime, data directory, memory settings, extensions | [server-overview.sql](../config/server-overview.sql) |
| Non-default settings, pending restarts, config file errors | [settings-review.sql](../config/settings-review.sql) |
| Current log file, logging settings | [log-settings-check.sql](../config/log-settings-check.sql) |
| pg_hba.conf rules, superusers, password hashing, SSL | [authentication-review.sql](../security/authentication-review.sql) |
| Database sizes | [database-sizes.sql](../storage/database-sizes.sql) |
| Largest tables and indexes, estimated rows | [table-and-index-sizes.sql](../storage/table-and-index-sizes.sql) |
| Active sessions and queries | [active-sessions.sql](../monitoring/active-sessions.sql) |
| Who is blocking whom | [blocking-locks.sql](../monitoring/blocking-locks.sql) |
| Dead rows, last vacuum and analyze | [vacuum-and-analyze-status.sql](../maintenance/vacuum-and-analyze-status.sql) |
| Replication status | [replication-status-primary.sql](../replication/replication-status-primary.sql) |
| Roles, memberships and privileges | [roles-and-memberships.sql](../security/roles-and-memberships.sql), [privileges-report.sql](../security/privileges-report.sql) |
| Read-only access | [create-read-only-role.sql](../security/create-read-only-role.sql) |
| Cancel a query, end a session, backup and restore | [50 shell and CLI commands](50-postgres-cli-commands.md) (31 to 39, 49) |
