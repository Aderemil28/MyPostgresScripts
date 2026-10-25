/*
Script  : replication-status-primary.sql
Purpose : Every standby (or logical subscriber) connected to this primary, with
          its state, sync mode, and how far behind it is, in bytes and in time.
          The Postgres view of what ag-replica-health.sql shows for an AG.
Usage   : Run on the PRIMARY. No rows means nothing is replicating from it.
          On AlloyDB and Cloud SQL, replication is managed by the service:
          use its replica lag metrics instead.
Changes : Read-only.
Requires: PostgreSQL 13 and later. pg_monitor (or superuser) to see all columns.
*/
SELECT  application_name,
        client_addr,
        state,                                                     -- streaming = healthy
        sync_state,                                                -- async, sync, potential, quorum
        pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), sent_lsn))   AS not_yet_sent,
        pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn)) AS replay_lag_size,
        write_lag,
        flush_lag,
        replay_lag,
        backend_start                                              AS connected_since
FROM pg_stat_replication
ORDER BY application_name;
