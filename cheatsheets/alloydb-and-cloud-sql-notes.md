# AlloyDB and Cloud SQL for PostgreSQL: what changes for the DBA

Both are managed PostgreSQL on Google Cloud. Most scripts in this repo work on them unchanged. These are the differences that matter day to day.

## You are not a superuser

- The admin role is `alloydbsuperuser` (AlloyDB) or `cloudsqlsuperuser` (Cloud SQL). It can create roles and databases but isn't a true superuser
- Anything that reads `pg_authid`, `pg_hba_file_rules`, `pg_file_settings` or server files won't work. The scripts that need superuser say so in their header
- `pg_dumpall --globals-only` needs `--no-role-passwords`

## Settings are database flags

- There is no `postgresql.conf` and `ALTER SYSTEM` isn't allowed. Settings are **database flags** on the instance (console, gcloud, or `database_flags` in Terraform)
- Some flags restart the instance when changed. Check before changing one in business hours
- `pg_stat_statements` is available: create the extension in each database you want to measure

## Connecting

- Usually by **private IP** inside the VPC, reached through private services access (the `gcp-private-service-access` module in MyTerraformScripts)
- The **AlloyDB Auth Proxy** / **Cloud SQL Auth Proxy** gives an IAM-authorized, encrypted connection without managing certificates
- **IAM database authentication** lets people and service accounts log in with their Google identity instead of a password

## High availability and replicas

- AlloyDB: the primary instance can be **regional** (a standby in another zone with automatic failover). **Read pool** instances serve read traffic
- Cloud SQL: `availability_type = REGIONAL` gives a standby with automatic failover. Read replicas are separate instances
- `pg_stat_replication` and replication slots are managed by the service: use the replica lag metrics in Cloud Monitoring

## Backups

- Automated backups and **point-in-time recovery** are configured on the cluster or instance, not with pg_basebackup
- AlloyDB has **continuous backup** with a recovery window in days, plus scheduled backups with their own retention
- A restore creates a **new** cluster or instance. It doesn't overwrite the existing one
- pg_dump is still useful for copies between environments, migrations and long-term exports

## Monitoring

- **Query Insights** shows top queries, waits and plans without extra setup
- Logs go to **Cloud Logging**: set `log_min_duration_statement` and related flags to choose what is logged
- AlloyDB adds the **columnar engine** for analytic queries (enabled with a flag); check with the application team before turning it on
