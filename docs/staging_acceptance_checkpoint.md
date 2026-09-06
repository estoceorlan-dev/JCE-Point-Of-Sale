# Staging acceptance checkpoint — 2026-09-06

Target: `jce-pos-staging-259528`, `asia-southeast1`, Cloud SQL
`jce-pos-instance`, database `jce-pos-database`. Production was not touched.

## Latest result: live database migration completed

- The operator granted the human IAM account temporary membership in
  `jce_pos_migrator`. A real IAM connection verified `SET LOCAL ROLE`, schema
  USAGE and CREATE before any migration.
- Fresh pre-migration backup: `C:/JCE/.backups/staging-GnZp8f/public.dump`,
  SHA-256 `82572712821e900fd79eb99f5c1d2317a74b3dc9f27d48432fb5cc2ed9154ee6`.
  All 39 original tables restored locally; corrected migrations and the
  role-grant regression rehearsal passed. The scratch server was stopped.
- Applied `0005`-`0011` to LIVE STAGING through the IAM migration runner.
  All 11 migration checksums now match. All 60 public tables remain owned by
  `jce_pos_migrator`; normalized branch-code duplicates remain zero.
- Applied `0011` SHA-256:
  `aa7381511ba3174f354f6adbb70d652e64a801c4446e4bb5836328b5939dc9ee`.
  It is now immutable: future corrections require a new migration. Git attributes
  preserve the existing LF bytes of SQL files across Windows checkouts.
- Post-migration two-connection locking primitive checks passed. This is not
  full signed-in business-command concurrency acceptance.
- Existing Functions and SQL Connect runtime identities have SELECT, INSERT and
  UPDATE access to all 60 public tables. No database permission repair or
  ownership transfer was needed/performed.
- SQL Connect diff proposed recreating existing migration-owned tables; no
  generated SQL was applied. Its existing remote schema uses validation NONE,
  as documented for this externally managed database. Schema/connector and
  Functions deployments have NOT yet been performed in this delivery.
- All 35 backend tests and lint passed again. Earlier Flutter checkpoint remains
  233 passing tests; this continuation did not change Flutter code.

The operator's temporary migration membership is still present. Remove it after
remaining deployment/permission verification, using the IAM operator guide.

## Historical checks before the live migration

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
- At the initial preflight, `origin/main` and local HEAD were both
  `60504e526ce065fc31c0ccbb3b69780c01662cc8`; the implementation checkpoint was
  subsequently pushed as `f313a2b`.

## Release blockers

### Corrected migration rehearsal

The subsequent live preflight reconfirmed `0011` was pending. Its role-name-based
permission grants were removed; it now seeds permission definitions only.
All 35 backend tests and lint pass, including two new migration policy checks.
The corrected migrations restored/rehearsed successfully against a fresh backup:
`C:/JCE/.backups/staging-Tojjaq/public.dump`, SHA-256
`32f6789f7206026a27c3e5098f85a5eabede70fafd4b7009f0797112ed78acae`.
The local rollback-only regression fixtures include owner/admin/uppercase/custom
role names, verify existing grants and grant timestamps are unchanged, and verify
migration replay does not elevate access. The scratch server was stopped.
This supersedes the earlier rehearsal for the corrected `0011`; no live schema
or privilege changes were made. See [IAM operator guide](staging_iam_access.md).

### Remaining prerequisites

1. No direct Firebase Authentication management grant was found for the Functions
   runtime service account. Its direct project roles are Cloud SQL Client,
   Cloud SQL Instance User, Logs Writer and Storage Object Admin. Approve and
   configure the required Auth access for identity lookup/creation, invite-link
   generation and refresh-token revocation before deploying the new workflows.
2. Only Windows, Chrome and Edge targets are connected. No Android terminal was
   detected. Installed Epson L5290 office printers are not evidence of a configured
   supported ESC/POS receipt printer or cash drawer. Printer address/model,
   scanner/drawer details and hands-on confirmation are needed for acceptance.
3. Approve explicit organization/role IDs for the new administration permissions
   and provision them deliberately; migration `0011` no longer grants them.
   The candidate found by active organization-wide assignment is Administrator,
   role `c32fa057-7995-4db9-bf75-27df81d7186b`, organization
   `17b463d6-a990-487a-ad55-b7c31b0edba8`. It currently has `users.manage` but not
   `branches.manage` or `roles.manage`. Approval was requested; no grants made.

Cloud-managed backups remain unavailable: the No Cost Trial rejected an on-demand
backup with HTTP 400 and automated backups are disabled. The verified logical
backup above supplies a limited application-schema recovery rehearsal, not
full-instance disaster recovery. No billing change was made.

## Actions deliberately not performed

Live staging migrations are completed as recorded above. No production changes,
Functions/schema/connector deployments, billing changes or application-role
grants were performed. Deployment remains paused at its prerequisites. Source
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
