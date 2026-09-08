# Admin operations and cashier POS — implementation checkpoint

Updated 2026-09-09. This tracks the requested **Phases 0–7**, separately from the
repository's historical Phase 15 hardware work. **The full delivery plan is not
complete. The staging backend plus Android and web clients are deployed; the
Windows client is built, and full pilot acceptance is pending.**
Existing hardware/receipt work is preserved.

## Working implementation

- Phase 3 continuation: staff search/status/branch/role filters combine, include
  organization-wide assignments in branch results, and can be cleared after a
  branch deep link. Branch and role must match the same assignment. Pending-sync
  counts react to local outbox changes and include failures/conflicts until
  resolved. Desktop and compact directory layouts support long labels and 150%
  text. Role-only administrators do not subscribe to staff/branch directories.
- Invitation binding now rechecks administration permission inside the existing
  organization access lock and matches the email at the write boundary. Inactive
  organizations cannot generate invitation bindings or pass acceptance replay.
  These backend fixes were deployed to staging on 2026-09-08.
- Shared ApprovalChallenge/ApprovalGrant/SupervisorApprovalService contracts and
  a rejecting default provider are present. **Secure enrollment and offline
  approvals remain unavailable.** See [credential design and gates](offline_supervisor_approvals.md).
- Manual cashier payment entry: cash starts empty, card/QR amounts require
  explicit external-payment confirmation, edits clear confirmation, and split
  Exact cash fills only the balance. Inputs lock during checkout. Automatic
  terminal integration is deferred until hardware/provider selection; see
  [manual payment workflow](manual_payment_workflow.md). This client change is
  in staging App Distribution and does not change remote hardware settings.
  A failed save after external confirmation now persists the stable operation
  ID, tender amounts/references, approval state, and reconciliation warning in
  the active cart across restart. The cart is locked against changes and only an
  explicit retry with the saved tender can commit it; no provider is retried.
- Phase 4 stock locations: managers can create, edit, archive and restore
  branch-scoped locations locally. Every mutation writes the location, audit
  record and outbox command in one SQLite transaction. Locations have optimistic
  versions; default changes advance each affected location version. Archive
  requires a non-default, non-last-active location with no on-hand/reserved
  stock, in-progress count or active transfer. Ledger history remains readable.
  The backend command, change-feed projection, guarded snapshot callable and
  `0013_stock_location_lifecycle.sql` were deployed to staging on 2026-09-08.
- Grouped navigation, `branches.manage` / `roles.manage`, Branches, and
  Staff & Access at `/staff`, with a compatibility redirect from `/users`.
- Drift schema 17: branch operational profiles and administration versions,
  staff invitation dates, normalized device-local active and held carts, and
  versioned stock locations seeded from known remote versions during upgrade.
  Active carts also retain stable checkout identity and external-payment
  recovery data locally.
- Offline branch create/edit/archive/restore, unique codes, pending-operation
  indicators, staff/register counts, and operational archival guards.
- Cached staff/role directories, profile and assignment edits, invites,
  status changes, permission editing, and role archival/restoration.
- Atomic local and server access checks prevent removal of the last full
  organization administrator and loss of the acting administrator's own access.
  Assignment changes now advance the staff version on both sides.
- Permission-scoped administration snapshots for organization-wide branch, staff,
  role, register and product administrators. Actor/permission-scoped hydration
  markers support access upgrades. Snapshot and incremental replay preserve pending
  edits; accepting a remote administration conflict restores the server projection
  atomically and leaves the conflict intact on failed recovery.
- Role-only Staff & Access navigation and a dedicated Registers & Hardware route;
  grouped compact navigation. Staff and role mutation controls retain their separate
  permissions. Existing hardware workflows remain available from POS.
- Branch details/deep links, operational-profile receipt headers, normalized
  branch-code duplicate guards, and server-confirmed cached branch selection.
  Refresh/revocation retains historical staff/assignment references.
- SQL Connect administration projections aligned and SDK generation validated.
- Online invitation generation/binding and authenticated acceptance callables.
  Invite URLs are transient; they are not written to audit, SQLite, or PostgreSQL.
- Tax-category lifecycle, explicit primary/multiple barcode editing,
  secondary-barcode lookup, register edit/archive/restore/device-unassignment.
- Catalog and opening-stock CSV templates, UTF-8/header validation, preview,
  row errors, duplicate checks, confirmation, atomic local rollback, and
  deterministic per-record audit/outbox operations.
- Catalog imports upsert by normalized SKU, append effective-dated organization
  prices when changed, and preserve branch overrides. Opening-stock imports
  reject product/location combinations with existing ledger history.
- Active/held cart persistence and revalidation. Payment waits for autosaves;
  a completed checkout removes only the current device's active cart inside
  the sale transaction. Held carts remain local and do not reserve stock.
- Responsive product browser/cart terminal, list/grid and category filters,
  customer/hold/resume/clear actions, F2/F4/F8/F9/Esc shortcuts, split tenders,
  cash presets, optional/required non-cash references, duplicate-submit guards,
  and access to existing shifts, transaction history, receipts and corrections.
- Phase 6 terminal completion adds an accessible touch number pad with strict
  two-decimal currency input, initial cash-field focus, F9 submit and Esc cancel
  inside payment, and accurate synced/offline/failed/queued terminal status.
  Product loading, empty and recoverable error states remain usable on compact
  screens and at 150% text. Confirmed external-payment recovery also blocks the
  F4/F8/Esc cart-changing shortcuts while preserving the exact saved F9 retry.
- The new terminal is gated by the `pos.terminal` feature flag; absent that
  flag, it is enabled only in demo mode. The legacy POS tabs remain available.

## Remaining work by requested phase

| Phase | Remaining exit requirements |
| --- | --- |
| 0 | Local navigation and hardware regression implementation is verified; native Windows/Android/web and physical-device acceptance remain. Startup tests own and close isolated databases without suppressing production Drift warnings. |
| 1 | Staging migrations through 0013 and backend deployment are complete. Broader live limited-permission/concurrency tests, connector query validation, and incremental-feed read-visibility review remain. Snapshot scopes, navigation, replay and atomic remote-conflict recovery now have regression coverage. Failed creations with no remote record remain explicit recovery cases. |
| 2 | Live two-device pending-branch selection/access-refresh acceptance and concurrent archival tests. Validate archived-history/reporting navigation without switching operational context into an archived branch. Directory/details and matching-branch receipt-profile rendering have desktop/compact and unit coverage. |
| 3 | Staff directory filters and pending indicators are implemented and locally tested. Approval contracts/design exist; **secure enrollment, encrypted/signed credentials, expiry/revocation, persistent lockout and workflow integrations are not implemented**. Invitation binding hardening is deployed; complete live mismatch/expiry/reactivation/regeneration and Firebase Auth identity tests. |
| 4 | Stock-location edit/archive/restore, Drift schema 16 version migration, backend lifecycle commands, archive guards and snapshot/change-feed convergence are implemented and covered locally. Migration 0013 and the ninth callable are deployed. Perform signed-in lifecycle, full command concurrency and two-device recovery tests. Measure 10,000-product/import/outbox performance; add broader tax/register/import widget coverage. |
| 5 | Persistent cart, held-cart, revalidation, atomic checkout, split-tender, and approved-external-payment restart recovery are implemented locally. Integrate the shared supervisor approval contract only after secure enrollment, signing, storage, replay claims, and server verification exist; expand fault-injection and end-to-end crash scenarios. |
| 6 | Numeric/touch payment entry, focus/shortcuts, loading/empty/error/offline states, long labels, large text and compact layouts are implemented and covered locally. Physical scanner/printer pilot acceptance remains. |
| 7 | PostgreSQL migration/concurrency integration tests, invite/credential negative tests, complete offline end-to-end scenarios, pilot performance measurements, admin/approval rollout flags, client rollout, reconciliation and user acceptance. Staging backend deployment is complete. |

Do not substitute a typed approver ID or locally stored plaintext PIN for the
remaining approval implementation. Current protected actions still use the
existing signed-in manager permission checks.

## CSV usage

Open **Products → Import CSV** or **Inventory → Import opening stock**.
Download the template or paste UTF-8 CSV, review every row, then confirm.
A file is limited to 5 MB / 10,000 data rows.

Catalog headers:

```csv
sku,name,unit_code,price,category,tax_code,barcodes,primary_barcode,description
```

Required: `sku,name,unit_code,price`. Omitted optional columns preserve existing
metadata; supplied empty category/tax/barcode values clear those values.
Use `|` between barcodes and choose exactly one primary when barcodes exist.
Units/categories/tax codes must already exist and be active.

Opening-stock headers:

```csv
sku,location_code,quantity
```

Prices use up to two decimal places; quantities use up to three, and whole-unit
products reject fractional opening stock. This is ledger initialization, not a
balance overwrite. The exact same confirmed file is idempotent in its scope.

## Verification at this checkpoint

- `flutter analyze`: no issues.
- `flutter test`: **278 tests passed** (2026-09-09), including location
  lifecycle, change-feed, schema-15-to-17 migration, stable checkout retry,
  external-payment restart recovery, cart-lock, corrupt-tender coverage, touch
  payment entry, terminal status states and compact/large-text POS states.
- Functions TypeScript build, `npm test`: **48 tests passed**, including
  location lifecycle and snapshot authorization coverage.
- `npm run lint`: passed, including the client-admin-provisioning security check.
- PostgreSQL 18 isolated rehearsal: migrations `0001`–`0013` applied in order;
  normalized-code and active-default duplicates were rejected, lifecycle lock
  queries executed, and an operation share lock blocked a concurrent archive
  update.
- Staging PostgreSQL: all 13 migration checksums match, all 60 public tables
  retain the migration owner, normalized-code duplicate groups are zero, and
  rollback-only shared/exclusive plus advisory lock checks passed without
  business writes.
- Staging Functions: all nine Node.js 22 callables are ACTIVE on source hash
  `d8872c8ea9511fe87163e5b937787a0de4c35665`; 18 unauthenticated probes
  returned HTTP 401 / UNAUTHENTICATED.
- The schema-17 Windows staging Release was rebuilt with `JCE_ENV=staging` and
  `JCE_ENABLE_DEMO_AUTH=false`. Executable SHA-256:
  `A44B899DAD045900BC0FC92402EF7E659AD3FA207F891ABDA01598B8ADC6359B`.
  It has not been installed on another device or physically accepted.
- Android staging release `0d3joe7dkcmo8`, version `1.0.0 (1)`, is available
  through Firebase App Distribution. APK SHA-256:
  `F93810AADE7EFBE37CFC4CDE7D7898908AB2B1942FC22A82554889B9A5D195A3`.
  No tester group was assigned automatically.
- The staging web administration client is deployed at
  `https://jce-pos-staging-259528.web.app` on Hosting version
  `4154aabde93c0a2f`. Live checks returned the Flutter shell for `/` and `/auth`
  and the correct JavaScript/WASM content types for the main bundle, Drift worker
  and SQLite runtime. Interactive browser acceptance remains pending.
- New local coverage: combined staff filters, reactive organization-scoped
  outbox counts, role-only read isolation, 360x640 layouts at 100%/150% text,
  durable external-payment save failure/restart and explicit stable retry,
  approval binding/expiry and rejecting enrollment/approval defaults. Invitation
  tests cover lock-before-authorization, changed identity data and
  inactive-organization replay denial.
- Startup cleanup tests: **2 passed**, with the multiple-instance warning removed.
- Terminal widget coverage: 1280×720, 1024×600, 800×700, 360×640; clear confirmation,
  search focus, repeated payment shortcuts, recovery-locked shortcuts, touch
  number-pad edits, offline/failed sync state, error retry and 150% text.
- New repository tests cover import rollback/idempotency/price preservation,
  opening-stock rejection, branch lifecycle/pending guards, staff invitation
  metadata, version progression, disablement, self-lockout and last-admin safety.
- Backend security tests use query doubles. They do **not** replace live
  PostgreSQL locking, Firebase Auth, staging, or physical-hardware acceptance.
- `git diff --check`: passed.
- SQL Connect SDK regeneration: succeeded for the aligned administration schema;
  schema/connector are now deployed to staging. Proposed SQL table recreation was not applied; existing externally managed validation NONE was preserved.
- Phase 0–2 regression coverage includes limited-role navigation, 1280×720 and
  360×640 branch layouts, pending branch selection, historical identity retention,
  normalized legacy code collisions, receipt numbering, snapshot scope upgrades,
  replay protection and failed/atomic remote-conflict recovery.

## Deployment order — staging backend, Android and web clients deployed; pilot acceptance pending

1. Back up and validate staging PostgreSQL; apply historical migrations through
   `0010_phase15_pos_hardware.sql`, then `0011_admin_operations.sql`,
   `0012_change_feed_tombstones.sql`, and only after the new normalized-code and
   active-default preflight passes, `0013_stock_location_lifecycle.sql`.
   **Completed on staging:** all 13 migrations applied,
   checksums verified, and all 60 public tables retain the migration owner.
2. **Completed on staging:** schema/connector and all nine Functions deployed,
   including `getStockLocationsSnapshot` and the lifecycle command source.
   Explicit Auth and application-role permissions provisioned with approval.
   New callables:
   `getAdministrationSnapshot`, `generateStaffInviteLink`,
   `acceptStaffInvitation`. Client function names remain configurable.
3. **Completed for staging artifacts:** the schema-17 Windows Release was rebuilt
   with demo auth disabled, the matching Android APK was uploaded to Firebase App
   Distribution, and the web administration fallback was deployed to staging
   Hosting. Install the complete Windows Release directory on the pilot terminal
   before acceptance. Pilot flags are unchanged.
4. Finish the outstanding security/lifecycle tests and approval implementation
   before enabling the requested protected offline workflows.
5. Enable only for the pilot branch after migration, sales/stock/shift
   reconciliation, device tests, performance measurement and acceptance.

No production environment or pilot settings were changed. Firebase staging
schema/connector, PostgreSQL migration 0013, Functions and the Android staging
and web client deployments are complete.

See [Phase 0–2 staging handoff](phase_0_2_validation.md) for the implemented
boundaries, normalized-code preflight, and outstanding external acceptance.
The local Docker Linux engine was unavailable for the earlier checkpoint.
Phase 4 was instead rehearsed against an isolated native PostgreSQL 18 cluster
and then deployed after a fresh staging backup/restore rehearsal. Query-double
coverage still does not substitute for signed-in lifecycle and full command
concurrency tests.

Subsequent direct staging checks verified IAM connectivity, existing migration
checksums, rollback-only locking primitives and unauthenticated Firebase rejection.
The staging public-schema logical backup restored all 39 tables into an isolated
local PostgreSQL cluster, and pending migrations `0005`-`0011` passed there.
The operator then granted migration-owner access and live staging migrations
through corrected `0011`, `0012` and `0013` completed. Approved application-admin
and Functions Auth grants are configured; staging backend deployment and a
signed-in branch/invite concurrency subset passed. Client installation, wider
live security/concurrency coverage and physical acceptance remain.
See [live staging checkpoint](staging_acceptance_checkpoint.md).
