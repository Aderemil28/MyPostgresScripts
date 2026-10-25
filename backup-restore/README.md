# Backup and restore

| File | What it does |
|---|---|
| [pg-backup.sh](pg-backup.sh) | pg_dump of every database (custom format), roles and tablespaces, read-back check, retention, log, non-zero exit on failure |

## Logical backups: pg_dump

A pg_dump backup is a consistent copy of **one database** at the moment the dump started. It doesn't include roles or tablespaces, which is why `pg-backup.sh` also runs `pg_dumpall --globals-only`.

```bash
# One database, custom format (compressed, restorable selectively, works with pg_restore -j)
pg_dump -h db01 -U backup_user -Fc -f appdb.dump appdb

# A big database: directory format, 4 parallel jobs
pg_dump -h db01 -U backup_user -Fd -j 4 -f appdb_dir appdb

# Roles and tablespaces (add --no-role-passwords on AlloyDB or Cloud SQL)
pg_dumpall -h db01 -U postgres --globals-only -f globals.sql

# Is the file readable, and what is in it?
pg_restore --list appdb.dump | head -40
```

## Restore a pg_dump backup

```bash
# 1. Roles first (once per server). Review the file: it can include roles you don't want on the target.
psql -h db02 -U postgres -d postgres -f globals.sql

# 2. Create an empty database
createdb -h db02 -U postgres -O app_owner appdb_restore

# 3. Restore with 4 parallel jobs, stop on the first error
pg_restore -h db02 -U postgres -d appdb_restore -j 4 --exit-on-error appdb.dump

# Restoring to a server where the original owners don't exist:
# the database must be owned by that role, and an admin creates the extensions first
createdb -h db02 -U postgres -O app_owner appdb_restore
psql -h db02 -U postgres -d appdb_restore -c "CREATE EXTENSION IF NOT EXISTS pg_stat_statements;"
pg_restore --list appdb.dump | grep -v " EXTENSION " > restore.list
pg_restore -h db02 -U postgres -d appdb_restore -j 4 --no-owner --role=app_owner --exit-on-error -L restore.list appdb.dump

# 4. Fresh planner statistics. pg_dump leaves them out unless you dumped with --statistics (PostgreSQL 18+)
psql -h db02 -U postgres -d appdb_restore -c "ANALYZE;"
```

Only one table:

```bash
pg_restore -h db02 -U postgres -d appdb_restore --table=customer --schema=app appdb.dump
```

## Physical backups and point-in-time recovery

pg_dump can only take you back to the moment of the dump. To restore to any point in time (the equivalent of SQL Server full plus log backups) you need a physical base backup plus continuous WAL archiving:

- `pg_basebackup` takes the base backup (`pg_basebackup -h db01 -U replicator -D /backups/base -Ft -z -P`)
- `archive_mode` and `archive_command` (or a tool such as pgBackRest or Barman) keep the WAL
- The restore sets `recovery_target_time` and replays WAL up to it

**On AlloyDB and Cloud SQL** the service does this for you: automated backups plus continuous backup / point-in-time recovery. Configure them in the service (see the MyTerraformScripts modules), and use pg_dump only for copies, migrations and long-term exports.

## Schedule it

```cron
# crontab -e for the backup user: every night at 01:30, keep 7 days
30 1 * * * PGHOST=db01 PGUSER=backup_user /opt/scripts/pg-backup.sh -o /backups/pg -r 7 >/dev/null 2>&1
```

The script exits 1 if anything failed, so your scheduler or monitoring can alert on it. The log is in the output folder.
