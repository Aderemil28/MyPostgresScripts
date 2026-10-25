# SQL Server to PostgreSQL: the DBA's map

What I already know from SQL Server, and where to find the same thing in PostgreSQL.

## Concepts

| SQL Server | PostgreSQL | Note |
|---|---|---|
| Instance | Cluster (one server, one data directory, one port) | "Cluster" here is not a failover cluster |
| Database | Database | You can't query across databases with three-part names; use `postgres_fdw` or `dblink` |
| Schema (dbo) | Schema (public) | Object lookup follows `search_path` |
| Login + database user | Role | One role object; `LOGIN` makes it a login, membership makes it a group |
| sysadmin | Superuser | Not available on AlloyDB / Cloud SQL: use `alloydbsuperuser` / `cloudsqlsuperuser` |
| Windows authentication | GSSAPI / LDAP on-prem; IAM database authentication on GCP | Set in pg_hba.conf on-prem |
| Transaction log | WAL (write-ahead log) | In `pg_wal` |
| tempdb | Temp files in each database's default tablespace (or `temp_tablespaces`) | |
| sp_configure / server properties | `postgresql.conf`, `ALTER SYSTEM`, `pg_settings` | Database flags on AlloyDB / Cloud SQL |

## Everyday DBA tasks

| SQL Server | PostgreSQL | In this repo |
|---|---|---|
| sp_who2 / sp_WhoIsActive / sys.dm_exec_requests | `pg_stat_activity` | [active-sessions.sql](../monitoring/active-sessions.sql) |
| Blocking (blocking_session_id) | `pg_blocking_pids()` | [blocking-locks.sql](../monitoring/blocking-locks.sql) |
| KILL spid | `pg_cancel_backend(pid)`, `pg_terminate_backend(pid)` | |
| Query Store / sys.dm_exec_query_stats | `pg_stat_statements` extension | [top-queries-pg-stat-statements.sql](../monitoring/top-queries-pg-stat-statements.sql) |
| Wait stats | `wait_event_type` / `wait_event` in `pg_stat_activity` (point in time) | [connections-and-waits.sql](../monitoring/connections-and-waits.sql) |
| UPDATE STATISTICS | `ANALYZE` | |
| Ghost cleanup / no direct equivalent | `VACUUM` and autovacuum (MVCC cleanup) | [vacuum-and-analyze-status.sql](../maintenance/vacuum-and-analyze-status.sql) |
| Index rebuild | `REINDEX INDEX CONCURRENTLY` | |
| DBCC CHECKDB | `amcheck` extension / `pg_amcheck` | |
| Full backup | `pg_dump` (logical) or `pg_basebackup` (physical) | [backup-restore](../backup-restore/) |
| Log backups and point-in-time restore | WAL archiving plus base backup | |
| Always On AG / log shipping | Streaming replication (physical) or logical replication; Patroni for automatic failover on-prem; HA built in on AlloyDB / Cloud SQL | [replication](../replication/) |
| SQL Agent jobs | `pg_cron` extension, or an external scheduler | |
| Linked server | `postgres_fdw` | |
| Error log | Server log (`log_directory`), or Cloud Logging on GCP | |

## Things that catch SQL Server people out

- **Unquoted names are folded to lower case.** `CREATE TABLE Customer` makes `customer`. Quote only if you must, and then always: `"Customer"`
- **DDL is transactional.** `BEGIN; DROP TABLE x; ROLLBACK;` brings the table back
- **There are no clustered indexes.** Tables are heaps; `CLUSTER` reorders once and doesn't keep the order
- **Readers don't block writers (MVCC).** There is no NOLOCK and no need for one. The cost is dead rows that vacuum must clean up
- **Long open transactions hurt more.** They stop vacuum cleaning up and can block DDL; watch for `idle in transaction`
- **Every connection is a process.** Connections are expensive: use a pooler such as PgBouncer for applications that open many
- **Transaction ID wraparound** is a real limit: autovacuum must keep up. See [transaction-id-wraparound.sql](../maintenance/transaction-id-wraparound.sql)

## T-SQL to PostgreSQL syntax

| T-SQL | PostgreSQL |
|---|---|
| `SELECT TOP (10) ...` | `SELECT ... LIMIT 10` |
| `ISNULL(a, b)` | `COALESCE(a, b)` |
| `GETDATE()` / `SYSDATETIME()` | `now()` / `clock_timestamp()` |
| `LEN(s)` | `length(s)` |
| `a + b` (strings) | `a \|\| b` or `concat(a, b)` |
| `IDENTITY(1,1)` | `GENERATED ALWAYS AS IDENTITY` |
| `NVARCHAR(n)` | `varchar(n)` or `text` (UTF8 database) |
| `DATETIME2` / `DATETIMEOFFSET` | `timestamp` / `timestamptz` |
| `BIT` | `boolean` |
| `UNIQUEIDENTIFIER` / `NEWID()` | `uuid` / `gen_random_uuid()` |
| `VARBINARY(MAX)` | `bytea` |
| `@variable` in a batch | Variables only inside `DO` blocks or functions (PL/pgSQL) |
| `EXEC proc` | `CALL proc()` (procedures) or `SELECT func()` (functions) |
| `BEGIN TRAN ... COMMIT` | `BEGIN; ... COMMIT;` |
| `sp_help table` | `\d+ table` in psql |
