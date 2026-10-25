# psql quick reference

## Connect

```bash
psql -h db01 -p 5432 -U app_user -d appdb
psql "host=db01 port=5432 dbname=appdb user=app_user sslmode=require"

# Run one command, or a file, and exit
psql -h db01 -U postgres -d appdb -c "SELECT version();"
psql -h db01 -U postgres -d appdb -f active-sessions.sql

# Tidy output for scripts: no psqlrc, unaligned, tuples only
psql -X -At -h db01 -U postgres -d postgres -c "SELECT datname FROM pg_database;"
```

Passwords go in `~/.pgpass` (one line per server, `chmod 600 ~/.pgpass`):

```text
db01:5432:*:app_user:the_password
```

## Inside psql

| Command | What it does |
|---|---|
| `\l` | List databases |
| `\c appdb` | Connect to another database |
| `\conninfo` | Who and where you are connected |
| `\dn` | List schemas |
| `\dt app.*` | List tables in schema app |
| `\d+ app.customer` | Columns, indexes, constraints, size of a table |
| `\di app.*` | List indexes |
| `\dv` / `\df` | List views / functions |
| `\du` | List roles and their attributes |
| `\dp app.customer` | Privileges on a table |
| `\dx` | Installed extensions |
| `\x auto` | Expanded output for wide rows |
| `\timing on` | Show how long each statement takes |
| `\watch 5` | Re-run the last query every 5 seconds |
| `\i file.sql` | Run a file |
| `\o out.txt` | Send output to a file (`\o` alone to stop) |
| `\copy app.customer TO 'customer.csv' CSV HEADER` | Export a table to CSV on your machine |
| `\password report_user` | Set a password without it appearing in history or logs |
| `\set ON_ERROR_STOP on` | Stop a script at the first error |
| `\q` | Quit |

## Useful one-liners

```sql
SELECT pg_size_pretty(pg_database_size(current_database()));
SELECT pg_cancel_backend(12345);      -- cancel a query
SELECT pg_terminate_backend(12345);   -- end a session
SELECT pg_reload_conf();              -- reload postgresql.conf / pg_hba.conf
EXPLAIN (ANALYZE, BUFFERS) SELECT ...;
```
