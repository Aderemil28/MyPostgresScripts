/*
Script  : replication-status-standby.sql
Purpose : On a standby: is it in recovery, is it receiving WAL from the
          primary, how far behind replay is, and when the last replayed
          transaction committed on the primary.
Usage   : Run on the STANDBY. On a primary, in_recovery is false and the
          other columns are empty.
          replay_delay grows when the primary is idle too (nothing new to
          replay), so compare received and replayed LSNs before raising an alarm.
Changes : Read-only.
Requires: PostgreSQL 13 and later. pg_monitor (or superuser) for pg_stat_wal_receiver.
*/

-- 1. Recovery and replay position
SELECT  pg_is_in_recovery()                                      AS in_recovery,
        pg_last_wal_receive_lsn()                                AS received_lsn,
        pg_last_wal_replay_lsn()                                 AS replayed_lsn,
        pg_size_pretty(pg_wal_lsn_diff(pg_last_wal_receive_lsn(),
                                       pg_last_wal_replay_lsn())) AS received_not_replayed,
        pg_last_xact_replay_timestamp()                          AS last_replayed_commit,
        now() - pg_last_xact_replay_timestamp()                  AS replay_delay;

-- 2. Connection to the primary
SELECT  status,                                                  -- streaming = healthy
        sender_host,
        sender_port,
        slot_name,
        last_msg_receipt_time,
        latest_end_lsn
FROM pg_stat_wal_receiver;
