# Admin operations and cashier POS — implementation checkpoint

Updated 2026-09-06. This tracks the requested **Phases 0–7**, separately from the
repository's historical Phase 15 hardware work. **The full delivery plan is not
complete and has not been deployed.** Existing hardware/receipt work is preserved.

## Working implementation

- Grouped navigation, `branches.manage` / `roles.manage`, Branches, and
  Staff & Access at `/staff`, with a compatibility redirect from `/users`.
- Drift schema 15: branch operational profiles and administration versions,
  staff invitation dates, normalized device-local active and held carts.
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
- The new terminal is gated by the `pos.terminal` feature flag; absent that
  flag, it is enabled only in demo mode. The legacy POS tabs remain available.

## Remaining work by requested phase

| Phase | Remaining exit requirements |
| --- | --- |
| 0 | Local navigation and hardware regression implementation is verified; native Windows/Android/web and physical-device acceptance remain. Startup tests own and close isolated databases without suppressing production Drift warnings. |
| 1 | Staging migration/schema-diff execution, live permission/concurrency tests, and incremental-feed read-visibility review. Snapshot scopes, navigation, replay and atomic remote-conflict recovery now have regression coverage. Failed creations with no remote record remain explicit recovery cases. |
| 2 | Live two-device pending-branch selection/access-refresh acceptance and concurrent archival tests. Validate archived-history/reporting navigation without switching operational context into an archived branch. Directory/details and matching-branch receipt-profile rendering have desktop/compact and unit coverage. |
| 3 | **Offline supervisor approvals are not implemented.** Deliver secure six-digit PIN enrollment, device-bound encrypted/signed credentials, expiry/revocation, lockout, ApprovalGrant contracts and all protected-workflow integrations. Complete branch/role filters and staff pending-sync indicators. Validate invite acceptance/reactivation/email-identity lifecycle against Firebase Auth. |
| 4 | Finish stock-location edit/archive/restore and remaining administration UX; measure 10,000-product/import/outbox performance; add broader tax/register/import widget and remote convergence tests. |
| 5 | Integrate the shared supervisor approval contract into discounts, corrections, stock operations, transfers, purchases, and shift discrepancies; expand failure/crash-recovery scenarios. |
| 6 | Complete numeric/touch payment entry, focus/shortcut and loading/error/offline golden coverage, long-label/large-text layouts, and physical scanner/printer pilot tests. |
| 7 | PostgreSQL migration/concurrency integration tests, invite/credential negative tests, complete offline end-to-end scenarios, pilot performance measurements, admin/approval rollout flags, staging deployment, reconciliation and user acceptance. |

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
- `flutter test`: **233 tests passed**.
- Functions TypeScript build and `npm test`: **33 tests passed**.
- `npm run lint`: passed, including the client-admin-provisioning security check.
- Startup cleanup tests: **2 passed**, with the multiple-instance warning removed.
- Terminal widget coverage: 1280×720, 1024×600, 800×700, 360×640; clear confirmation,
  search focus and repeated payment shortcuts.
- New repository tests cover import rollback/idempotency/price preservation,
  opening-stock rejection, branch lifecycle/pending guards, staff invitation
  metadata, version progression, disablement, self-lockout and last-admin safety.
- Backend security tests use query doubles. They do **not** replace live
  PostgreSQL locking, Firebase Auth, staging, or physical-hardware acceptance.
- `git diff --check`: passed.
- SQL Connect SDK regeneration: succeeded for the aligned administration schema;
  no deployment or live database schema diff was performed.
- Phase 0–2 regression coverage includes limited-role navigation, 1280×720 and
  360×640 branch layouts, pending branch selection, historical identity retention,
  normalized legacy code collisions, receipt numbering, snapshot scope upgrades,
  replay protection and failed/atomic remote-conflict recovery.

## Deployment order — staging database complete; application deployment pending

1. Back up and validate staging PostgreSQL; apply historical migrations through
   `0010_phase15_pos_hardware.sql`, then `0011_admin_operations.sql`.
   **Completed on staging:** corrected migrations through `0011` applied,
   checksums verified, and all 60 public tables retain the migration owner.
2. Build/deploy Functions and review SQL Connect changes. New callables:
   `getAdministrationSnapshot`, `generateStaffInviteLink`,
   `acceptStaffInvitation`. Client function names remain configurable.
3. Deploy the schema-15 client to staging with `pos.terminal` disabled.
4. Finish the outstanding security/lifecycle tests and approval implementation
   before enabling the requested protected offline workflows.
5. Enable only for the pilot branch after migration, sales/stock/shift
   reconciliation, device tests, performance measurement and acceptance.

No production database, Firebase deployment, or pilot settings were changed.

See [Phase 0–2 staging handoff](phase_0_2_validation.md) for the implemented
boundaries, normalized-code preflight, and outstanding external acceptance.
The local Docker Linux engine was unavailable, so live PostgreSQL tests were not
substituted with query-double test results.

Subsequent direct staging checks verified IAM connectivity, existing migration
checksums, rollback-only locking primitives and unauthenticated Firebase rejection.
The staging public-schema logical backup restored all 39 tables into an isolated
local PostgreSQL cluster, and pending migrations `0005`-`0011` passed there.
The operator then granted migration-owner access and live staging migrations
through corrected `0011` completed. Remaining prerequisites are approved
application-admin grants, Functions Firebase Auth access, backend/client
deployment, signed-in command concurrency and physical acceptance.
See [live staging checkpoint](staging_acceptance_checkpoint.md).
