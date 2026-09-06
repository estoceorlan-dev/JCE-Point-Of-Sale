# Staging acceptance checkpoint — 2026-09-06

Target: `jce-pos-staging-259528`, `asia-southeast1`, Cloud SQL
`jce-pos-instance`, database `jce-pos-database`. Production was not touched.

## Verified live

- Firebase CLI credentials can access staging. Cloud SQL reports `RUNNABLE`.
- Direct IAM PostgreSQL connectivity works. Migrations `0001`–`0004` match their
  recorded SHA-256 checksums; `0005`–`0011` are pending.
- No organization has duplicate normalized branch codes.
- A logical backup of the staging `public` schema was restored into an isolated
  local PostgreSQL 18 cluster: all 39 public tables restored successfully, then
  pending migrations `0005` through `0011` applied successfully. The scratch
  server was stopped afterward. This is a local rehearsal, not a live migration.
- Backup: `C:/JCE/.backups/staging-MHNulp/public.dump` (196,727 bytes), SHA-256
  `3330a7409ff3b191937b97d5f86479debf25cdab0398eae8d461d0b73959bd4e`.
  The adjacent manifest records verification. The backup directory has restricted
  user/SYSTEM access and is outside Git. The archive includes public-schema
  ownership/ACL metadata, but the local restore used `--no-owner --no-acl`:
  cloud-role/ACL restoration, global roles, other schemas and Firebase Auth are
  not covered. Refresh the backup immediately before any eventual live migration.
- Two real database connections verified shared branch locks block exclusive
  locks, exclusive locks succeed after rollback, and transaction advisory locks
  serialize and release correctly. No business rows were written. This tests
  locking primitives, not full shift/transfer/archive command concurrency.
- Four concurrent unauthenticated requests to `getMyAccessProfile` and
  `applyRemoteCommand` returned HTTP 401 / `UNAUTHENTICATED`.
  Signed-in workflow concurrency and the new administration callables remain
  unverified against the updated schema.
- `origin/main` is at `60504e526ce065fc31c0ccbb3b69780c01662cc8`, matching local HEAD.

## Release blockers

1. The connected IAM user is not a member of `jce_pos_migrator`, which owns all
   39 public tables, and cannot create objects in `public`. No privileges were
   granted and no alternative privileged identity was assumed.
2. Only Windows, Chrome and Edge targets are connected. No Android terminal was
   detected. Installed Epson L5290 office printers are not evidence of a configured
   supported ESC/POS receipt printer or cash drawer. Printer address/model,
   scanner/drawer details and hands-on confirmation are needed for acceptance.

Cloud-managed backups remain unavailable: the No Cost Trial rejected an on-demand
backup with HTTP 400 and automated backups are disabled. The verified logical
backup above supplies a limited application-schema recovery rehearsal, not
full-instance disaster recovery. No billing change was made.

## Actions deliberately not performed

No live migrations, deployments, privilege/billing changes or remote business-data
mutations were performed. Deployment remains paused at its prerequisites. Source
checkpoint commit/push is separate from release acceptance: the repository's CI
workflow runs verification only and contains no deployment job. Credentials,
backups and the existing `android/build/` artifacts are excluded from the source
checkpoint. A source commit does not mean Phase 0-2 has passed live acceptance.

## Reusable checks

Scripts in `backend/functions/scripts` accept explicit staging identifiers and
standard Google application credentials. They never print credential contents:

- `staging-preflight.js`: Cloud SQL state, backups and configured database users.
  `--create-backup` explicitly requests an on-demand staging backup.
- `staging-database-check.js`: checksum, normalized-code and privilege checks.
  `--check-locks` performs rollback-only two-connection lock checks.
- `staging-callable-check.js`: concurrent unauthenticated negative probes only.
- `staging-logical-backup.js`: read-only remote dump, isolated local restore and
  migration rehearsal. Requires an existing access-restricted backup directory
  outside the repository and installed PostgreSQL dump/restore/server tools.

Environment names: `GOOGLE_APPLICATION_CREDENTIALS`, `JCE_STAGING_PROJECT`,
`JCE_STAGING_INSTANCE`, `JCE_FUNCTIONS_REGION`, `JCE_DB_INSTANCE_CONNECTION_NAME`,
`JCE_DB_NAME`, `JCE_DB_USER`, `JCE_BACKUP_DIRECTORY`, and `JCE_POSTGRES_BIN`.
Choose only those required by each script.
