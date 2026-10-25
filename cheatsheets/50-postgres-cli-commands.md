# 50 PostgreSQL shell and CLI commands

The commands I use most from a Linux shell, grouped by task. Each one has what it does, when to use it, and the command itself with comments.

Placeholders used throughout. Replace them with your own:

| Placeholder | Meaning |
|---|---|
| `db01` | Server host name |
| `5432` | Port |
| `appdb` | Database |
| `app_owner` | Role that owns the application objects |
| `$PGDATA` | Data directory, for example `/var/lib/postgresql/18/main` on Ubuntu or `/var/lib/pgsql/18/data` on Red Hat |

> [!TIP]
> Set `PGHOST`, `PGPORT`, `PGUSER` and `PGDATABASE` once and most commands below no longer need `-h -p -U -d`:
> `export PGHOST=db01 PGPORT=5432 PGUSER=postgres PGDATABASE=appdb`

> [!NOTE]
> Server-side commands (`pg_ctl`, `initdb`, `pg_controldata`, `pg_waldump`, `pg_rewind` and the like) run on the database server as the `postgres` OS user, for example after `sudo -iu postgres`. On AlloyDB and Cloud SQL you have no server shell, so use only the client tools there: `psql`, `pg_isready`, `pg_dump`, `pg_restore`, `vacuumdb`, `reindexdb`, `pgbench`.

## Connecting and running SQL (1 to 10)

**1. Connect to a database.** The starting point for everything else.

```bash
psql -h db01 -p 5432 -U postgres -d appdb
```

**2. Connect with a connection string.** Useful when you need options such as SSL mode or an application name.

```bash
psql "host=db01 port=5432 dbname=appdb user=postgres sslmode=require application_name=dba_check"
```

**3. Run one SQL statement and exit.** Quick checks without opening a session.

```bash
psql -h db01 -U postgres -d appdb -c "SELECT version();"
```

**4. Run a script file, stopping at the first error.** Without `ON_ERROR_STOP`, psql carries on after an error and returns success.

```bash
psql -h db01 -U postgres -d appdb -v ON_ERROR_STOP=1 -f monitoring/active-sessions.sql
echo "exit code: $?"      # 0 = success, 3 = a statement in the script failed
```

**5. Get clean output for shell scripts.** `-X` ignores your .psqlrc, `-A` unaligned, `-t` rows only: one value per line, ready for a loop.

```bash
for db in $(psql -X -At -h db01 -U postgres -d postgres \
            -c "SELECT datname FROM pg_database WHERE datallowconn AND NOT datistemplate"); do
    echo "Database: $db"
done
```

**6. Export a query to CSV.** For handing results to someone else (PostgreSQL 12 and later).

```bash
psql -X -h db01 -U postgres -d appdb --csv \
     -c "SELECT * FROM pg_stat_user_tables ORDER BY n_dead_tup DESC" > table_stats.csv
```

**7. Check the server is accepting connections.** Exit code 0 means ready; ideal for scripts and health checks.

```bash
pg_isready -h db01 -p 5432
# db01:5432 - accepting connections   (exit 0)
# 1 = rejecting (starting up or shutting down), 2 = no response, 3 = bad parameters
```

**8. List the databases on a server.**

```bash
psql -h db01 -U postgres -l
```

**9. Store passwords in .pgpass.** So scripts and cron jobs connect without a prompt and without a password on the command line. psql ignores the file unless only you can read it.

```bash
echo "db01:5432:*:backup_user:the_password" >> ~/.pgpass
chmod 600 ~/.pgpass
```

**10. Use a named service.** Keep connection details in `~/.pg_service.conf` and connect by name.

```bash
cat >> ~/.pg_service.conf <<'EOF'
[appdb-prod]
host=db01
port=5432
dbname=appdb
user=dba_user
sslmode=require
EOF

psql "service=appdb-prod"
```

## Starting, stopping and checking the server (11 to 20)

**11. Is the server running, and with which data directory?**

```bash
pg_ctl status -D "$PGDATA"
```

**12. Start the server and write startup messages to a file.**

```bash
pg_ctl start -D "$PGDATA" -l /tmp/pg_startup.log -w      # -w waits until it is ready
```

**13. Stop the server.** `fast` (the default) disconnects sessions and rolls back their transactions. `smart` waits for everyone to leave. `immediate` is a crash-stop that needs recovery on the next start: last resort only.

```bash
pg_ctl stop -D "$PGDATA" -m fast
```

**14. Restart the server.** Needed after changing a setting whose context is `postmaster` (for example `shared_buffers`, `logging_collector`).

```bash
pg_ctl restart -D "$PGDATA" -m fast -l /tmp/pg_startup.log
```

**15. Reload the configuration without a restart.** For postgresql.conf and pg_hba.conf changes whose context is `sighup` or lower.

```bash
pg_ctl reload -D "$PGDATA"
# or from any session, as superuser:
psql -h db01 -U postgres -c "SELECT pg_reload_conf();"
```

**16. Manage the service through systemd.** On a packaged install, use systemd rather than pg_ctl so the OS knows the state. Ubuntu names the unit after the version and cluster.

```bash
sudo systemctl status postgresql@18-main      # Ubuntu / Debian
sudo systemctl restart postgresql-18          # Red Hat family
sudo journalctl -u postgresql@18-main --since "1 hour ago"
```

**17. List the clusters on a Debian or Ubuntu server.** Shows version, port, status, data directory and log file for each.

```bash
pg_lsclusters
```

**18. Read the control file.** The cluster's state, last checkpoint, WAL position and whether data checksums are on, even when the server is down.

```bash
pg_controldata -D "$PGDATA" | grep -E "cluster state|Latest checkpoint location|checksum"
```

**19. Which version are the tools?** Client tools should be the same major version as the server, or newer, especially pg_dump.

```bash
psql --version
pg_dump --version
pg_config --version
```

**20. Create a new cluster.** Data checksums detect storage corruption. From PostgreSQL 18 initdb turns them on by default (`--no-data-checksums` turns them off); on older versions add `--data-checksums`, because adding them later needs the server stopped. The locale must be installed on the server (`locale -a` lists them).

```bash
initdb -D /var/lib/postgresql/18/newcluster --data-checksums --encoding=UTF8 --locale=en_US.UTF-8 --auth-local=peer --auth-host=scram-sha-256
```

## Databases, roles and maintenance (21 to 30)

**21. Create a database owned by the application role.**

```bash
createdb -h db01 -U postgres -O app_owner -E UTF8 appdb
```

**22. Drop a database.** `--force` (PostgreSQL 13 and later) disconnects everyone first. Take a backup before you run this.

```bash
dropdb -h db01 -U postgres --if-exists --force appdb_old
```

**23. Create a login role and be prompted for its password.** The password never appears in shell history.

```bash
createuser -h db01 -U postgres --login --pwprompt report_user
```

**24. Drop a role.** Fails if the role still owns objects or holds privileges: reassign or drop those first (`REASSIGN OWNED BY ... TO ...; DROP OWNED BY ...;` in each database).

```bash
dropuser -h db01 -U postgres --if-exists report_user
```

**25. Vacuum and analyze every database.** After a large data load, or when autovacuum has fallen behind.

```bash
vacuumdb -h db01 -U postgres --all --analyze --jobs=4
```

**26. Fresh statistics fast after an upgrade or restore.** Builds rough statistics first so the planner can work, then refines them. From PostgreSQL 18, pg_upgrade carries the statistics across, so add `--missing-stats-only` to analyze only what is missing.

```bash
vacuumdb -h db01 -U postgres --all --analyze-in-stages                        # after a restore, or an upgrade to 17 or earlier
vacuumdb -h db01 -U postgres --all --analyze-in-stages --missing-stats-only   # after pg_upgrade to 18 or later
```

**27. Vacuum one table and show what it did.**

```bash
vacuumdb -h db01 -U postgres -d appdb --table='app.orders' --verbose --analyze
```

**28. Rebuild indexes without blocking writes.** `--concurrently` (PostgreSQL 12 and later) takes longer but doesn't lock out the application. It does wait for transactions that were already open when it started, so if it seems stuck, look for an old open transaction with [blocking-locks.sql](../monitoring/blocking-locks.sql).

```bash
reindexdb -h db01 -U postgres -d appdb --table='app.orders' --concurrently
```

**29. Check tables and indexes for corruption.** The closest thing to DBCC CHECKDB (PostgreSQL 14 and later). `--install-missing` creates the amcheck extension if needed.

```bash
pg_amcheck -h db01 -U postgres -d appdb --install-missing --heapallindexed --progress
```

**30. Benchmark a server.** pgbench creates test tables and runs a TPC-B-like load. Use a scratch database, never production.

```bash
createdb -h db01 -U postgres benchdb
pgbench -h db01 -U postgres -i -s 50 benchdb               # load: scale 50 = 5 million rows
pgbench -h db01 -U postgres -c 10 -j 2 -T 60 -P 10 benchdb # 10 clients, 60 seconds, progress every 10 s
```

## Backup and restore (31 to 40)

**31. Back up one database in custom format.** Compressed, and lets pg_restore pick objects and run in parallel. The usual choice.

```bash
pg_dump -h db01 -U postgres -Fc -f appdb_$(date +%Y%m%d).dump appdb
```

**32. Back up a large database in parallel.** Directory format with several jobs.

```bash
pg_dump -h db01 -U postgres -Fd -j 4 -f appdb_dir appdb
```

**33. Schema only.** For comparing environments, or rebuilding an empty copy.

```bash
pg_dump -h db01 -U postgres --schema-only -f appdb_schema.sql appdb
```

**34. One table only (with its data).**

```bash
pg_dump -h db01 -U postgres -Fc -t app.orders -f orders.dump appdb
```

**35. Back up roles and tablespaces.** pg_dump doesn't include them. Add `--no-role-passwords` on AlloyDB / Cloud SQL or when you aren't a real superuser.

```bash
pg_dumpall -h db01 -U postgres --globals-only -f globals.sql
```

**36. See what is inside a backup file.** Also proves the file is readable.

```bash
pg_restore --list appdb.dump | head -40
```

**37. Restore into a new database, in parallel, stopping on the first error.**

```bash
createdb -h db02 -U postgres -O app_owner appdb_restore
pg_restore -h db02 -U postgres -d appdb_restore -j 4 --exit-on-error appdb.dump
```

**38. Restore where the original owners don't exist.** Everything ends up owned by the role you choose. Two things make this work: the new database must be **owned by that role** (so it can create schemas), and **extensions** must be created first by an admin, because an ordinary role can't create or comment on them. The restore list then skips the extension entries.

```bash
createdb -h db02 -U postgres -O app_owner appdb_restore
psql -h db02 -U postgres -d appdb_restore -c "CREATE EXTENSION IF NOT EXISTS pg_stat_statements;"   # each extension the source uses

pg_restore --list appdb.dump | grep -v " EXTENSION " > restore.list       # everything except extensions
pg_restore -h db02 -U postgres -d appdb_restore --no-owner --role=app_owner -j 4 --exit-on-error -L restore.list appdb.dump
```

**39. Copy a database between servers in one step.** No file in between; both servers must be reachable from where you run it.

```bash
createdb -h db02 -U postgres appdb_copy
pg_dump -h db01 -U postgres appdb | psql -X -h db02 -U postgres -d appdb_copy -v ON_ERROR_STOP=1 -q
```

**40. Take a physical base backup and check it.** The whole cluster, for point-in-time recovery or building a standby. `pg_verifybackup` (PostgreSQL 13 and later) checks it against its manifest.

```bash
pg_basebackup -h db01 -U replicator -D /backups/base_$(date +%Y%m%d) -Fp -X stream -P --checkpoint=fast
pg_verifybackup /backups/base_$(date +%Y%m%d)
```

## Replication and WAL (41 to 45)

**41. Build a streaming standby from the primary.** `-R` writes the standby settings, `-C -S` creates a replication slot for it. Run on the new standby server, into an empty data directory.

```bash
pg_basebackup -h db01 -U replicator -D "$PGDATA" -X stream -P -R -C -S standby_db02 --checkpoint=fast
pg_ctl start -D "$PGDATA" -l /tmp/pg_startup.log
```

**42. Promote a standby to primary.** For failover or a planned switchover. Make sure the old primary is down or fenced first.

```bash
pg_ctl promote -D "$PGDATA"
# or from a session on the standby:
psql -h db02 -U postgres -c "SELECT pg_promote();"
```

**43. Bring an old primary back as a standby without a full rebuild.** After a failover, pg_rewind copies only the changed blocks. Needs `wal_log_hints = on` or data checksums, and the old primary must be stopped cleanly.

```bash
pg_ctl stop -D "$PGDATA" -m fast
pg_rewind -D "$PGDATA" --source-server="host=db02 port=5432 user=postgres dbname=postgres" --progress --write-recovery-conf
```

**44. Look inside WAL files.** To see what was happening at a given point (which tables were written, how much), for example before a point-in-time restore.

```bash
pg_waldump "$PGDATA"/pg_wal/000000010000000000000005 | head -20
pg_waldump --stats=record "$PGDATA"/pg_wal/000000010000000000000005   # summary by record type
```

**45. Clean up an archive of WAL files no longer needed.** Removes files older than the one named (the oldest still needed by a backup or standby). `-n` shows what would go first.

```bash
pg_archivecleanup -n /archive/wal 000000010000000000000010   # dry run
pg_archivecleanup /archive/wal 000000010000000000000010
```

## Troubleshooting from the shell (46 to 50)

**46. Watch active sessions refresh every 5 seconds.**

```bash
watch -n 5 'psql -X -h db01 -U postgres -d appdb -c "SELECT pid, usename, state, wait_event, now() - query_start AS runtime, left(query, 60) AS query FROM pg_stat_activity WHERE state <> '\''idle'\'' AND pid <> pg_backend_pid() ORDER BY runtime DESC"'
```

**47. Find and follow the current server log.**

```bash
psql -X -At -h db01 -U postgres -c "SELECT pg_current_logfile();"     # path relative to $PGDATA
tail -f "$PGDATA/$(psql -X -At -U postgres -c 'SELECT pg_current_logfile()')"
grep -E "ERROR|FATAL|PANIC" "$PGDATA"/log/postgresql-*.log | tail -50
```

**48. See the Postgres processes on the server.** Each connection is its own process, and the process title shows user, database, client and state.

```bash
ps -o pid,etime,pcpu,rss,args -u postgres --sort=-pcpu | head -20
```

**49. End a session from the shell.** `pg_cancel_backend` stops the query only; `pg_terminate_backend` ends the session and rolls back its transaction.

```bash
psql -X -h db01 -U postgres -c "SELECT pg_cancel_backend(12345);"
psql -X -h db01 -U postgres -c "SELECT pg_terminate_backend(12345);"
```

**50. Check a major version upgrade before doing it.** `--check` makes no changes: it reports incompatibilities between the old and new clusters. Run it with the **new** version's pg_upgrade. Both servers must be stopped for the real run.

```bash
/usr/lib/postgresql/18/bin/pg_upgrade --check \
    --old-bindir=/usr/lib/postgresql/17/bin --new-bindir=/usr/lib/postgresql/18/bin \
    --old-datadir=/var/lib/postgresql/17/main --new-datadir=/var/lib/postgresql/18/main
```

## See also

- [psql quick reference](psql-quick-reference.md) for the commands inside psql (`\d`, `\x`, `\watch` and so on)
- [Log management parameters](log-management-parameters.md)
- [Backup and restore guide](../backup-restore/)
