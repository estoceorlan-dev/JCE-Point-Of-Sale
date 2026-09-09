# Staging acceptance checkpoint — 2026-09-10

Target: `jce-pos-staging-259528`, `asia-southeast1`, Cloud SQL
`jce-pos-instance`, database `jce-pos-database`. Production was not touched.

## Result: staging backend, Android and web clients deployed; full acceptance remains open

The 2026-09-08 backend deployment includes invitation binding hardening,
stock-location lifecycle commands, `getStockLocationsSnapshot`, and migration
`0013_stock_location_lifecycle.sql`. The 2026-09-10 schema-18 client release adds
the catalog lookup indexes found necessary by Phase 7 performance validation; it
also includes durable payment-save reconciliation and the completed Phase 6
terminal UI. Its Windows bundle remains pending pilot installation; its Android
APK is in staging App Distribution, and its web administration fallback is on
staging Hosting.
Offline supervisor approvals remain gated. Backend query-double tests do not
replace signed-in PostgreSQL/Firebase workflow acceptance.

- Migrations through `0013_stock_location_lifecycle.sql` are applied. All 13
  checksums match; all 60 public tables remain owned by `jce_pos_migrator`.
  Normalized branch-code duplicate groups remain zero.
- The operator's temporary human IAM membership in `jce_pos_migrator` remains
  present. IAM SET LOCAL ROLE and schema USAGE/CREATE were verified.
- Corrected migration 0011 seeds permissions only, without role-name-based
  grants. Its live SHA-256 is
  `aa7381511ba3174f354f6adbb70d652e64a801c4446e4bb5836328b5939dc9ee`.
  Applied migrations are immutable; Git preserves SQL LF bytes for checksums.
- Live testing exposed a constraint rejecting backend `tombstone` feed events.
  The failed archive transaction rolled back. New migration 0012 allows
  upsert/delete/tombstone without rewriting history. Fresh backup, local restore,
  migration rehearsal and regression tests passed before live application.
- Functions and SQL Connect runtime identities retain SELECT/INSERT/UPDATE on all
  60 tables. No ownership transfer or runtime migration-role grant occurred.

## Explicitly approved permission changes

- Runtime identity:
  `jce-pos-functions@jce-pos-staging-259528.iam.gserviceaccount.com`.
- Custom project role `jcePosStaffIdentityManager` grants only
  `firebaseauth.users.create`, `firebaseauth.users.get`,
  `firebaseauth.users.sendEmail`, and `firebaseauth.users.update`.
  An etag-protected IAM update preserved existing bindings. No Auth deletion,
  session creation or broad Firebase Auth Admin grant.
- Organization `17b463d6-a990-487a-ad55-b7c31b0edba8`, role
  `c32fa057-7995-4db9-bf75-27df81d7186b`: added only `branches.manage` and
  `roles.manage` after verifying the signed-in administrator's organization-wide
  assignment. Existing permissions were preserved; role version advanced to 1.
- Audit operation `staging-admin-permissions-20260906`, action
  `role.permissions.provision`, and an organization-wide role feed event record
  provisioning. No passwords, tokens or invitation links were persisted by the
  operator scripts.

## Deployed artifacts

- SQL Connect schema `main` source updated with etag protection after contract
  validation. SHA-256 of JSON source:
  `2478621ad377bc82b8ace1018f81a928ad71398ac5466baa60de32990c1fc31c`.
  Updated 2026-09-06 15:03:59 UTC.
- Connector `jce-pos-service:pos-connector` deployed successfully.
  Existing remote SQL validation NONE was preserved. Generated SQL proposing
  recreation of migration-owned tables was NOT applied. Contract deployment
  does not establish compatibility of every connector query.
- All nine Node.js 22 Functions deployed using the intended runtime identity:
  getMyAccessProfile, registerDevice, updateBranchName, applyRemoteCommand,
  finalizeProductImage, generateStaffInviteLink, acceptStaffInvitation and
  getAdministrationSnapshot, plus getStockLocationsSnapshot. Functions source
  hash: `d8872c8ea9511fe87163e5b937787a0de4c35665`.
- Schema-18 Windows staging release from commit `38b8b1b`, built with demo
  authentication disabled:
  `build/windows/x64/runner/Release/jce_pos.exe`.
  SHA-256:
  `A44B899DAD045900BC0FC92402EF7E659AD3FA207F891ABDA01598B8ADC6359B`.
  Application payload `data/app.so` SHA-256:
  `1C1872BC756AB86F9C26173296023352E2294AA5EEB9A84A56D009DAB9913E55`.
  Copy/install the entire Release directory, including DLLs and data.
  Native launch and physical acceptance were not verified in this continuation.
- Android staging release `2dul4b9b7umlo`, version `1.0.0 (1)`, uploaded to
  Firebase App Distribution without a tester group. APK SHA-256:
  `29538012C1B4AC1C39BC066411C6CF546C0A12D0B991EF05E40CED2C559CAF1F`.
- Web staging release deployed to `https://jce-pos-staging-259528.web.app` as
  Hosting version `815d116f50af2c5a`. The local and live SHA-256 of
  `main.dart.js` is
  `FE781A0FFCAACB76D3B4AA187C61629BCE49D2CBE303F12923EBD42665345405`.
  Live HTTP checks passed for the root shell, `/branches` SPA fallback, main bundle,
  Drift worker and SQLite WASM MIME type. Visual browser acceptance is pending.
- No production, billing, storage-rule or pilot feature-flag changes.
  Committing/pushing source does not install the client; CI verifies code only.

## Verified acceptance subset

Real Firebase sessions and deployed callables passed:

- Administrator access includes the approved administration permissions.
- Invitation creates/binds a separate QA identity, generates a transient setup
  URL, completes password setup, activates the matching profile, and handles
  repeated acceptance idempotently.
- Four concurrent administration snapshots succeed; a branch-scoped QA cashier
  cannot retrieve an administration snapshot.
- Four identical concurrent branch-create commands produce exactly one branch,
  audit entry, feed entry and processed operation; three return duplicate.
- Two version-zero edits commit once; the stale writer receives ABORTED.
- Cashier administration and unauthorized branch access are denied. An unknown
  organization is denied; this does not replace an existing foreign-org test.
- Current-branch archive is rejected; archive, archived-edit rejection and
  restore pass after migration 0012.
- Staff disablement revokes assignments and refresh tokens; the old session
  cannot load access. QA roles/branches were archived and staff disabled, with
  audit/history retained. Firebase Auth identities were not physically deleted.
- Eighteen unauthenticated requests (two per deployed callable) all
  returned HTTP 401 / UNAUTHENTICATED.
- All 13 staging migration checksums match. Rollback-only branch shared/exclusive
  locking and transaction advisory-lock checks passed without business writes.

Successful run fixtures: branch `e68da74a-8f85-48d9-969a-d9d7e37264c4`,
staff `67cb530d-a8ed-4a62-8e5a-1d241aef14cb`,
role `4334dd35-cbb0-46eb-b13a-acfabd76293b`.
The failed-run fixtures were also archived/disabled after the fix.
Saved Cashier credentials did not authenticate in staging and were unchanged.
QA accounts used random in-memory passwords and example.invalid addresses;
no invitation email was sent.

Local verification: 48 backend tests, TypeScript build and lint passed.
Flutter verification: 292 tests passed, one opt-in performance test was skipped,
and formatting and analyze passed. The Windows and Android staging releases were
built with demo authentication disabled.

## Backups and recovery boundaries

- Before 0005–0011: `C:/JCE/.backups/staging-GnZp8f/public.dump`,
  SHA-256 `82572712821e900fd79eb99f5c1d2317a74b3dc9f27d48432fb5cc2ed9154ee6`;
  all 39 original tables restored and migration rehearsal passed.
- Before 0012: `C:/JCE/.backups/staging-OrGUgm/public.dump`,
  328,398 bytes, SHA-256
  `a87fb675eeda935544a0177ac6be63d136957dd10a75f70b071d810abc1e1332`;
  all 60 tables restored and migration/permission regression rehearsal passed.
- Before 0013: `C:/JCE/.backups/staging-nAimoT/public.dump`,
  331,962 bytes, SHA-256
  `a94c0e83e066c179433dd64eda9232e260d90f023220c4369a5a65cfaa8b5b70`;
  all 60 tables restored, migration 0013 rehearsed, and administration grant
  preservation checks passed before the live migration.
- Previous SQL Connect schema:
  `C:/JCE/.backups/schema-release-zd5tyE/previous-schema.json`.
- Backups are access-restricted and outside Git; scratch servers were stopped.
  Restore rehearsals used --no-owner/--no-acl: live ACL recovery, global roles,
  other schemas and Firebase Auth are outside their scope.
- No Cost Trial rejected cloud-managed backup creation; automated backups are
  disabled. Logical backups are not full-instance disaster recovery.

## Remaining release gates

1. Two-device offline branch creation/restart/sync/access-refresh/selection and
   registration; incremental-feed visibility and convergence.
2. Limited-admin permission isolation, existing foreign-organization denial,
   last-administrator races, archive versus shift/count/transfer races.
3. Invitation mismatch/expiry/reactivation/regeneration negative cases and
   remaining staff identity lifecycle checks.
4. Native Windows/Android/web smoke and physical ESC/POS printer/scanner/drawer
   acceptance: offline sale, reprint, scan input and disconnected hardware
   without rolling back a committed sale. Office printers alone are not evidence.
5. Pilot performance, stock/sales/shift reconciliation and user acceptance.
   Offline supervisor credentials remain unimplemented.
6. Remove temporary human migration membership using the authorized PostgreSQL
   role administrator once database work is finished.

## Reusable operator checks

Scripts under `backend/functions/scripts` require explicit staging identifiers
and existing application credentials; never print secret values.

- `staging-preflight.js`: Cloud SQL state, users and backups.
- `staging-database-check.js`: checksums, duplicates, ownership;
  `--check-locks` optionally checks rollback-only locking primitives.
- `staging-logical-backup.js`: public-schema backup and local restore/rehearsal.
- `staging-callable-check.js`: unauthenticated probes for all nine callables.
- `staging-auth-permissions.js`: preview; `--apply` configures the exact Auth
  role/binding. Requires JCE_FUNCTIONS_SERVICE_ACCOUNT and JCE_AUTH_ROLE_ID.
- `staging-admin-permissions.js`: preview; `--apply` provisions approved IDs
  with audit/feed. Requires JCE_ACCESS_ORGANIZATION_ID, JCE_ACCESS_ROLE_ID,
  JCE_ACCESS_OPERATION_ID and JCE_DB_MIGRATION_ROLE.
- `staging-deploy-schema.js`: validates the contract; `--apply` backs up and
  updates source only on an existing externally managed schema. Requires
  JCE_SQL_CONNECT_SERVICE and JCE_BACKUP_DIRECTORY.
- `staging-signed-in-check.js --run`: creates QA fixtures through deployed
  callables, then archives/disables them. Requires JCE_TEST_CREDENTIALS_FILE
  with an Administrator section and JCE_ACCESS_ORGANIZATION_ID.
  Add JCE_FOREIGN_ORGANIZATION_ID and `--require-foreign-organization` to verify
  snapshot and mutation denial against an approved existing unassigned staging
  organization. This required Phase 7 variant has not yet been executed.
  Review emitted fixture IDs and complete cleanup manually if interrupted.

Common environment: GOOGLE_APPLICATION_CREDENTIALS, JCE_STAGING_PROJECT,
JCE_FUNCTIONS_REGION, JCE_DB_INSTANCE_CONNECTION_NAME, JCE_DB_NAME, JCE_DB_USER.
Backup rehearsal also needs JCE_POSTGRES_BIN and a restricted external directory.
Credentials/backups/build outputs are excluded from Git; unrelated
`android/build/` artifacts are preserved.

See [IAM setup and cleanup](staging_iam_access.md),
[Phase 0–2 handoff](phase_0_2_validation.md), and
[hardware scenarios](phase_15_pos_hardware.md).
