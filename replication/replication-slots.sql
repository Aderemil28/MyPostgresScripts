/*
Script  : replication-slots.sql
Purpose : Replication slots and how much WAL each one is holding back. An
          inactive slot keeps WAL on the primary forever and is the most
          common reason a Postgres disk fills up.
Usage   : Run on the PRIMARY. A slot with active = false and a large
          retained_wal is either a standby or subscriber that is down, or one
          that no longer exists. Confirm with its owner, then drop it:
              SELECT pg_drop_replication_slot('slot_name');
Changes : Read-only.
Requires: PostgreSQL 13 and later (wal_status and safe_wal_size columns).
*/
SELECT  slot_name,
        slot_type,                                                 -- physical or logical
        database,
        plugin,
        active,
        active_pid,
        wal_status,                                                -- reserved, extended, unreserved, lost
        pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn)) AS retained_wal,
        pg_size_pretty(safe_wal_size)                              AS safe_wal_size
FROM pg_replication_slots
ORDER BY pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn) DESC NULLS LAST;

-- max_slot_wal_keep_size caps how much WAL a slot may hold (-1 = no limit)
SELECT name, setting, unit FROM pg_settings WHERE name = 'max_slot_wal_keep_size';
