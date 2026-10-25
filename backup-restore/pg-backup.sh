#!/usr/bin/env bash
# Script  : pg-backup.sh
# Purpose : Logical backup of every database on a server (or the ones you name)
#           with pg_dump in custom format, plus roles and tablespaces with
#           pg_dumpall --globals-only. Checks each dump can be read back,
#           deletes backups older than the retention, and writes a log.
#           Exits non-zero if any database fails, so a scheduler sees it.
# Usage   : ./pg-backup.sh -o /backups/pg [-r 7] [-n] [db1 db2 ...]
#             -o  output folder (required)
#             -r  retention in days (default 7)
#             -n  --no-role-passwords for the globals dump (needed on AlloyDB,
#                 Cloud SQL and anywhere you are not a real superuser)
#           Connection comes from the usual libpq variables:
#             PGHOST=db01 PGPORT=5432 PGUSER=backup_user ./pg-backup.sh -o /backups/pg
#           Put the password in ~/.pgpass (chmod 600), never on the command line.
# Changes : Writes backup files to the output folder and deletes files there
#           older than the retention.
# Requires: pg_dump and pg_dumpall of the same major version as the server, or
#           newer. A role that can read every table it backs up.
# Notes   : For large databases use directory format with parallel jobs
#           (pg_dump -Fd -j 4). For point-in-time recovery you need physical
#           backups and WAL archiving (pg_basebackup, pgBackRest), not pg_dump.

set -euo pipefail

retention_days=7
no_role_passwords=0
out_dir=""

while getopts ":o:r:n" opt; do
    case "$opt" in
        o) out_dir="$OPTARG" ;;
        r) retention_days="$OPTARG" ;;
        n) no_role_passwords=1 ;;
        *) echo "Usage: $0 -o <output folder> [-r days] [-n] [database ...]" >&2; exit 2 ;;
    esac
done
shift $((OPTIND - 1))

if [[ -z "$out_dir" ]]; then
    echo "Usage: $0 -o <output folder> [-r days] [-n] [database ...]" >&2
    exit 2
fi
if ! [[ "$retention_days" =~ ^[0-9]+$ ]]; then
    echo "Retention must be a whole number of days" >&2
    exit 2
fi

mkdir -p "$out_dir"
stamp="$(date +%Y%m%d_%H%M%S)"
server="${PGHOST:-localhost}"
log="$out_dir/pg-backup_${stamp}.log"

log_msg() { printf '%s %s\n' "$(date '+%F %T')" "$*" | tee -a "$log"; }

# Databases to back up: the ones named, or every database that accepts connections
if [[ $# -gt 0 ]]; then
    databases=("$@")
else
    mapfile -t databases < <(psql -X -At -d postgres -c \
        "SELECT datname FROM pg_database WHERE datallowconn AND NOT datistemplate ORDER BY datname")
fi

log_msg "Backup of ${#databases[@]} database(s) on $server to $out_dir (retention $retention_days days)"
failed=0

# Roles and tablespaces
globals_file="$out_dir/${server}_globals_${stamp}.sql"
globals_args=(--globals-only --file="$globals_file")
[[ $no_role_passwords -eq 1 ]] && globals_args+=(--no-role-passwords)
if pg_dumpall "${globals_args[@]}" 2>>"$log"; then
    log_msg "OK    globals -> $(basename "$globals_file")"
else
    log_msg "FAIL  globals (see the log for the error)"
    failed=$((failed + 1))
fi

# Each database
for db in "${databases[@]}"; do
    file="$out_dir/${server}_${db}_${stamp}.dump"
    start=$SECONDS
    if pg_dump --format=custom --compress=6 --file="$file" --dbname="$db" 2>>"$log" \
       && pg_restore --list "$file" >/dev/null 2>>"$log"; then
        size="$(du -h "$file" | cut -f1)"
        log_msg "OK    $db -> $(basename "$file") ($size, $((SECONDS - start))s)"
    else
        log_msg "FAIL  $db (see the log for the error)"
        rm -f "$file"
        failed=$((failed + 1))
    fi
done

# Retention: only files this script creates
deleted=$(find "$out_dir" -maxdepth 1 -type f \
    \( -name '*.dump' -o -name '*_globals_*.sql' -o -name 'pg-backup_*.log' \) \
    -mtime +"$retention_days" -print -delete | wc -l)
log_msg "Retention removed $deleted old file(s)"

if [[ $failed -gt 0 ]]; then
    log_msg "Finished with $failed failure(s)"
    exit 1
fi
log_msg "Finished OK"
