# The 10 most important PostgreSQL log management parameters

The server log is where PostgreSQL tells you about errors, slow queries, lock waits, connections and schema changes. Out of the box it logs very little and the files can grow without limit. These 10 parameters decide **where** the log goes, **how it rotates**, and **what goes in it**.

Defaults below are PostgreSQL 18's. Check yours with [config/log-settings-check.sql](../config/log-settings-check.sql).

| # | Parameter | Default | Recommended | Takes effect after |
|---|---|---|---|---|
| 1 | `logging_collector` | `off` | `on` | **Restart** |
| 2 | `log_destination` | `stderr` | `stderr` (add `jsonlog` for log tools) | Reload |
| 3 | `log_directory` | `log` | `log`, or a dedicated volume | Reload |
| 4 | `log_filename` | `postgresql-%Y-%m-%d_%H%M%S.log` | `postgresql-%a.log` | Reload |
| 5 | `log_rotation_age` | `1d` | `1d` | Reload |
| 6 | `log_rotation_size` | `10MB` | `0` (with the weekly cycle) | Reload |
| 7 | `log_truncate_on_rotation` | `off` | `on` (with the weekly cycle) | Reload |
| 8 | `log_line_prefix` | `%m [%p] ` | `%m [%p] %quser=%u db=%d app=%a client=%h ` | Reload |
| 9 | `log_min_duration_statement` | `-1` (off) | `1000` (1 second) | Reload |
| 10 | `log_statement` | `none` | `ddl` | Reload |

## How to change them

```sql
-- As a superuser. ALTER SYSTEM writes postgresql.auto.conf, which overrides postgresql.conf.
ALTER SYSTEM SET log_min_duration_statement = '1000';
SELECT pg_reload_conf();                       -- for every parameter except logging_collector

-- logging_collector needs a restart:  pg_ctl restart -D "$PGDATA"  (or systemctl restart)

-- Check what is live, and whether anything is waiting for a restart
SELECT name, setting, unit, source, pending_restart FROM pg_settings WHERE name LIKE 'log%';

-- Undo a change made with ALTER SYSTEM
ALTER SYSTEM RESET log_min_duration_statement;
SELECT pg_reload_conf();
```

Parameters 9 and 10 can also be set for **one database or one role**, so you can log more for a single application without flooding the log:

```sql
ALTER DATABASE appdb SET log_min_duration_statement = '500';
ALTER ROLE batch_user SET log_min_duration_statement = '-1';   -- don't log the overnight batch
```

## Where the log goes (1 to 3)

### 1. logging_collector

**What it does:** starts a background process that captures the server's output and writes it to log files that PostgreSQL rotates itself. Without it, output goes wherever the service manager sends it (the journal on systemd, or a file named in `pg_ctl -l`), and parameters 3 to 7 do nothing.

**Why it matters:** it's the only reliable way to get rotated, named log files that `pg_current_logfile()` can point you to.

```ini
logging_collector = on        # needs a restart; the only parameter here that does
```

> [!NOTE]
> Debian and Ubuntu packages leave this `off` and write `/var/log/postgresql/postgresql-18-main.log` through their own wrapper and logrotate. That works, but you then manage rotation with logrotate rather than with parameters 4 to 7.

### 2. log_destination

**What it does:** the format(s) to write. `stderr` is plain text. `csvlog` and `jsonlog` (PostgreSQL 15 and later) write structured files next to it, which log shippers and SIEM tools parse without regular expressions. `syslog` (and `eventlog` on Windows) send to the OS logger. You can list more than one.

```ini
log_destination = 'stderr'              # plain text, readable with tail and grep
#log_destination = 'stderr,jsonlog'     # also a .json file for Splunk, Elastic or similar
```

`csvlog` and `jsonlog` need `logging_collector = on`.

### 3. log_directory

**What it does:** the folder for the log files. A relative path is inside the data directory (`$PGDATA/log`). An absolute path can put logs on their own volume.

**Why it matters:** if the log and the data share a disk, a runaway log (for example `log_statement = 'all'` left on) can fill the disk and stop the database.

```ini
log_directory = 'log'                     # $PGDATA/log
#log_directory = '/pglog/18/main'         # dedicated volume; must exist and be owned by postgres
```

## How it rotates (4 to 7)

There are two good patterns. Pick one.

**Pattern A, a weekly cycle (recommended for most servers).** One file per weekday, overwritten a week later. Disk use is bounded and nothing needs cleaning up:

```ini
log_filename = 'postgresql-%a.log'      # postgresql-Mon.log ... postgresql-Sun.log
log_rotation_age = 1d                   # new file at midnight
log_rotation_size = 0                   # no size-based rotation, one file per day
log_truncate_on_rotation = on           # overwrite last week's file instead of appending
```

**Pattern B, keep everything and clean up yourself.** Every file has a timestamp. Use it when you must keep logs longer than a week or ship them elsewhere:

```ini
log_filename = 'postgresql-%Y-%m-%d_%H%M%S.log'
log_rotation_age = 1d
log_rotation_size = 100MB
log_truncate_on_rotation = off
```

```bash
# Delete files older than 30 days (cron, as postgres)
find "$PGDATA/log" -name 'postgresql-*.log' -mtime +30 -delete
```

### 4. log_filename

**What it does:** the file name pattern, using `strftime` escapes: `%Y` year, `%m` month, `%d` day, `%H%M%S` time, `%a` weekday, `%j` day of the year.

**Why it matters:** the name decides whether files are reused (pattern A) or pile up (pattern B).

### 5. log_rotation_age

**What it does:** starts a new file after this much time. `1d` gives one file a day; `1h` suits a very busy server. `0` turns time-based rotation off.

### 6. log_rotation_size

**What it does:** starts a new file when the current one reaches this size. `0` turns size-based rotation off.

**Why it matters:** with pattern A it must be `0`. A size-based rotation would reuse the same weekday name and, because truncation happens only on time-based rotation, keep appending to it.

### 7. log_truncate_on_rotation

**What it does:** when a time-based rotation lands on a file name that already exists, overwrite it instead of appending.

**Why it matters:** it is what makes pattern A a cycle. With it `off`, `postgresql-Mon.log` would grow every Monday forever.

## What goes in it (8 to 10)

### 8. log_line_prefix

**What it does:** the text at the start of every log line. The default (`%m [%p] `) gives only the time and process ID, so you can't tell who caused an error.

```ini
log_line_prefix = '%m [%p] %quser=%u db=%d app=%a client=%h '
```

| Escape | Meaning |
|---|---|
| `%m` | Time with milliseconds |
| `%p` | Process ID (matches `pid` in `pg_stat_activity`) |
| `%q` | Stop here for background processes, which have no user or database |
| `%u` / `%d` | User / database |
| `%a` | Application name (set `application_name` in connection strings) |
| `%h` | Client host or IP |
| `%x` | Transaction ID (add it when you investigate locking) |

This format is also one that log analyzers such as pgBadger can read.

### 9. log_min_duration_statement

**What it does:** logs every statement that takes longer than this many milliseconds, with its duration and text. The PostgreSQL slow-query log.

**Why it matters:** it is the cheapest way to find the queries that hurt, and it keeps working when `pg_stat_statements` has been reset.

```ini
log_min_duration_statement = 1000      # log statements over 1 second; -1 = off, 0 = everything
```

Start at 1 second on a busy OLTP server and lower it while you tune. `0` logs every statement: never on a busy production server.

### 10. log_statement

**What it does:** logs statements by type, regardless of how long they take: `none`, `ddl` (CREATE, ALTER, DROP), `mod` (DDL plus INSERT, UPDATE, DELETE, TRUNCATE, COPY FROM) or `all`.

**Why it matters:** `ddl` gives you an audit trail of schema changes (who dropped that index, and when) at almost no cost.

```ini
log_statement = 'ddl'
```

`mod` and `all` can produce huge logs and write sensitive values in plain text. For real audit requirements use the **pgaudit** extension, which logs by object and class and is available on AlloyDB and Cloud SQL.

> [!WARNING]
> Statements in the log include their literal values. `log_statement = 'all'` or `log_min_duration_statement = 0` can write customer data and passwords set with `ALTER ROLE ... PASSWORD` into the log. Restrict access to the log directory, and use `\password` in psql to set passwords.

## Also worth turning on

| Parameter | Recommended | What you get |
|---|---|---|
| `log_lock_waits` | `on` | A line whenever a session waits longer than `deadlock_timeout` (1 s) for a lock, with who holds it |
| `log_checkpoints` | `on` (default since 15) | Checkpoint timing and buffers written: shows I/O pressure |
| `log_connections` / `log_disconnections` | `on` | Who connected from where, and session length. Often an audit requirement. From PostgreSQL 18, `log_connections` takes a list of stages (`receipt`, `authentication`, `authorization`, `setup_durations`, or `all`); `on` still works and means the first three |
| `log_autovacuum_min_duration` | `10s` | Autovacuum runs that take longer than 10 seconds, with what they cleaned |
| `log_temp_files` | `10MB` | Queries spilling sorts or hashes to disk: candidates for `work_mem` or tuning |
| `log_min_error_statement` | `error` (default) | The statement that caused each error |

## A complete starting block

Paste into `postgresql.conf` (or apply with `ALTER SYSTEM`), then restart once for `logging_collector`:

```ini
# Where
logging_collector = on
log_destination = 'stderr'
log_directory = 'log'

# Rotation: weekly cycle
log_filename = 'postgresql-%a.log'
log_rotation_age = 1d
log_rotation_size = 0
log_truncate_on_rotation = on

# What
log_line_prefix = '%m [%p] %quser=%u db=%d app=%a client=%h '
log_min_duration_statement = 1000
log_statement = 'ddl'
log_lock_waits = on
log_checkpoints = on
log_connections = on
log_disconnections = on
log_autovacuum_min_duration = 10s
log_temp_files = 10MB
```

## Reading the log

```bash
psql -X -At -c "SELECT pg_current_logfile();"                       # current file, relative to $PGDATA
tail -f "$PGDATA/log/postgresql-$(date +%a).log"                    # follow today's file
grep -E "ERROR|FATAL|PANIC" "$PGDATA/log/postgresql-$(date +%a).log" | tail -50
grep -o "duration: [0-9.]* ms .*" "$PGDATA/log/postgresql-$(date +%a).log" | sort -k2 -rn | head   # slowest statements
```

```sql
-- From SQL (pg_monitor or superuser): log files and their sizes
SELECT name, pg_size_pretty(size) AS size, modification FROM pg_ls_logdir() ORDER BY modification DESC;
```

## On AlloyDB and Cloud SQL

The service manages parameters 1 to 8: logs go to **Cloud Logging**, where you search and keep them with log-based retention and sinks. Parameters 9 and 10 and the "also worth turning on" list are **database flags** (console, gcloud, or `database_flags` in the MyTerraformScripts modules). Query Insights covers much of what the slow-query log does.
