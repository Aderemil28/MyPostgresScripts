# MyPostgresScripts

My personal PostgreSQL toolkit: monitoring, storage, maintenance, replication, security and backup scripts for day-to-day DBA work, plus cheat sheets for moving from SQL Server to PostgreSQL, AlloyDB and Cloud SQL.

Every script has a header saying what it does, how to run it, whether it changes anything, and what it needs. Read-only scripts are safe to run any time; the few that change something say so in the **Changes** line.

All scripts were run against PostgreSQL 16 (a primary and a streaming standby) during validation, both as a superuser and as a role with only `pg_monitor`. The two that need superuser for some sections say so in their header.

## Monitoring

| Script | What it answers |
|---|---|
| [active-sessions.sql](monitoring/active-sessions.sql) | Who is running what right now, waits, who is blocking them (the sp_WhoIsActive of Postgres) |
| [blocking-locks.sql](monitoring/blocking-locks.sql) | Blocked sessions, their blockers, and the head of each blocking chain |
| [long-running-queries.sql](monitoring/long-running-queries.sql) | Queries over a threshold, and sessions sitting idle in a transaction |
| [top-queries-pg-stat-statements.sql](monitoring/top-queries-pg-stat-statements.sql) | Top 20 queries by total time (needs pg_stat_statements) |
| [connections-and-waits.sql](monitoring/connections-and-waits.sql) | Connections used vs max_connections, who holds them, current waits |
| [database-stats.sql](monitoring/database-stats.sql) | Cache hit ratio, commits, rollbacks, deadlocks and temp files per database |

## Storage

| Script | What it answers |
|---|---|
| [database-sizes.sql](storage/database-sizes.sql) | Size of every database, largest first |
| [table-and-index-sizes.sql](storage/table-and-index-sizes.sql) | Largest tables (heap, index, TOAST) and largest indexes |
| [tablespaces-wal-and-temp.sql](storage/tablespaces-wal-and-temp.sql) | Tablespace sizes, WAL directory size, temp files written |

## Maintenance

| Script | What it answers |
|---|---|
| [vacuum-and-analyze-status.sql](maintenance/vacuum-and-analyze-status.sql) | Dead rows, last (auto)vacuum and analyze, vacuums running now |
| [transaction-id-wraparound.sql](maintenance/transaction-id-wraparound.sql) | How close each database is to XID wraparound, and what blocks freezing |
| [index-review.sql](maintenance/index-review.sql) | Unused indexes, duplicate indexes, foreign keys with no index |
| [terminate-sessions-for-database.sql](maintenance/terminate-sessions-for-database.sql) | List, then end, every session in one database (**changes**: ends sessions) |

## Replication

| Script | What it answers |
|---|---|
| [replication-status-primary.sql](replication/replication-status-primary.sql) | Run on the primary: each standby's state, sync mode and lag |
| [replication-status-standby.sql](replication/replication-status-standby.sql) | Run on a standby: receiving and replaying, and how far behind |
| [replication-slots.sql](replication/replication-slots.sql) | Slots and the WAL each one holds (the usual cause of a full disk) |

## Security

| Script | What it answers |
|---|---|
| [roles-and-memberships.sql](security/roles-and-memberships.sql) | Every role, its attributes, password expiry and group memberships |
| [privileges-report.sql](security/privileges-report.sql) | Database, schema, table and default privileges in the current database |
| [authentication-review.sql](security/authentication-review.sql) | Superusers, passwords that never expire, md5 vs scram, SSL sessions, pg_hba rules |
| [create-read-only-role.sql](security/create-read-only-role.sql) | Template: least-privilege read-only group and login, including default privileges (**changes**: creates roles) |

## Configuration

| Script | What it answers |
|---|---|
| [server-overview.sql](config/server-overview.sql) | Version, uptime, primary or standby, memory settings, databases, extensions |
| [settings-review.sql](config/settings-review.sql) | Non-default settings, pending restarts, config file errors, the review list |

## Backup and restore

| File | What it does |
|---|---|
| [pg-backup.sh](backup-restore/pg-backup.sh) | pg_dump of every database plus roles, read-back check, retention, log, non-zero exit on failure (**changes**: writes and prunes backup files) |
| [Backup and restore guide](backup-restore/) | pg_dump / pg_restore commands, single-table restore, physical backups and PITR, scheduling |

## Cheat sheets

| Sheet | |
|---|---|
| [SQL Server to PostgreSQL](cheatsheets/sql-server-to-postgres.md) | Concepts, everyday DBA tasks, gotchas and T-SQL to PostgreSQL syntax |
| [psql quick reference](cheatsheets/psql-quick-reference.md) | Connecting, .pgpass, the backslash commands I use most |
| [AlloyDB and Cloud SQL notes](cheatsheets/alloydb-and-cloud-sql-notes.md) | What changes on managed PostgreSQL in Google Cloud |

## Running a script

```bash
psql -h <host> -U <user> -d <database> -f monitoring/active-sessions.sql
```

Most scripts need nothing more than the `pg_monitor` role. Grant it to a DBA login with `GRANT pg_monitor TO dba_user;`.

## Related

- [MySqlScripts](https://github.com/Aderemil28/MySqlScripts): my SQL Server toolkit
- [MyTerraformScripts](https://github.com/Aderemil28/MyTerraformScripts): Terraform for AlloyDB and Cloud SQL for PostgreSQL
- [SQL Server Docs](https://github.com/Aderemil28/sql-server-docs): my step-by-step runbooks
