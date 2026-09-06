# Phases 0–2 validation and staging handoff

## Local implementation

- Desktop navigation is grouped and permission-filtered. Compact navigation has
  quick destinations plus a grouped **More** sheet.
- Organization-scoped branch administrators use `/branches` and
  `/branches/:branchId`. Role-only administrators can open `/staff`; staff actions
  still require `users.manage`, and role actions require `roles.manage`.
- `/registers` exposes register/hardware administration without requiring POS
  sales permission. Existing POS register/shift workflows remain available.
- Snapshots support organization-wide branch, role, user, register and product
  administrators. Staff/access graphs are returned only for user/role management;
  branch/register-only snapshots omit staff identities. Completion markers are
  keyed by organization, actor and permission set, so upgrades trigger hydration.
- Snapshot replay and incremental administration updates preserve unresolved
  local mutations. Accepting a remote administration conflict fetches a fresh
  snapshot before atomically discarding the command and restoring the projection.
  Network failure, an unavailable record, or additional pending edits leave the
  conflict unresolved. Remote-missing failed creations require explicit recovery;
  they are not silently deleted.
- Access-cache refresh/revocation preserves historical staff/assignment rows.
  Cached branch selection is restricted to the last server-confirmed branch list
  and excludes unaccepted branch creations. Directory hydration cannot grant access.
- Branch details show the operational profile, cached counts, pending warnings,
  and permission-filtered links to staff, registers, inventory, settings and audit.
  Opening operational links explicitly selects an accepted active branch.
- Receipts render the matching branch's display name/address/contact profile.
  Editing a branch code does not change persisted historical receipt numbers.
- SQL Connect includes branch/register/tax projections and staff invitation fields.

## PostgreSQL preflight (staging only)

Back up staging first. The normalized branch-code index intentionally fails if
legacy records conflict; do not automatically rename those records.

```sql
SELECT organization_id, upper(btrim(code)) AS normalized_code, count(*)
FROM branches
GROUP BY organization_id, upper(btrim(code))
HAVING count(*) > 1;
```

Resolve any returned duplicates through an approved migration. Apply migrations
through `0010_phase15_pos_hardware.sql`, then `0011_admin_operations.sql`, before
deploying Functions/SQL Connect and the schema-15 client. Do not alter checksums of
already applied migrations; if staging already has an earlier `0011`, add a new
migration for the normalized index instead.

Before live application, `0011` was corrected to seed permission definitions without
assigning privileges to roles named `owner` or `admin`. Explicitly approve
organization/role IDs and organization-wide assignments before administration
rollout. The existing account-provisioning script does not grant role permissions.
See [staging IAM access](staging_iam_access.md) for operator setup and verification.

## Outstanding external acceptance

Local checkpoint: 233 Flutter tests and 35 Functions tests pass. SQL Connect SDK
generation succeeded. These checks include the preserved hardware/receipt and
released Drift migration tests, not live device or PostgreSQL acceptance.

Live staging migrations `0005`-`0011` are now applied after a fresh backup and
successful local restore/rehearsal. All 11 checksums match; all 60 tables remain
migration-owned. PostgreSQL locking primitive checks pass. Firebase application
deployment, pilot flag changes and complete signed-in workflow concurrency remain
pending. See [staging checkpoint](staging_acceptance_checkpoint.md).

Before calling all Phase 0–2 exit criteria complete:

1. Validate migration order/checksums and SQL Connect schema diff against staging.
2. Exercise each limited administration permission with real Firebase accounts;
   verify cross-organization and branch-only mutation rejection and review
   incremental-feed read visibility separately from snapshot permissions.
3. Create a branch offline, restart, synchronize, refresh access, select it, and
   verify device registration and branch-scoped operations on a second device.
4. Race archival against shift opening, stock counts and transfers using two live
   database connections. Confirm archived branches reject new operations.
5. Verify branch detail links after switching context and archived-history access
   with the intended reporting permissions. Detail pages deliberately do not
   switch operational context to an archived branch.
6. Run native Windows/Android/web smoke tests and the physical scanner/printer/
   drawer failure scenarios in `phase_15_pos_hardware.md`.

Offline supervisor credentials, remaining stock administration, and terminal
payment enhancements are still separate Phase 3–6 work.
