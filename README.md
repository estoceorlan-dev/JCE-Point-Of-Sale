# JCE POS

Offline-first Flutter foundation for a scalable, multi-branch point of sale and
inventory system.

## Supported production platforms

- Windows: primary desktop POS and administration client
- Android: mobile POS and operational client
- Web: administration and operational fallback; hardware-specific POS flows
  remain Windows/Android responsibilities

The generated Linux, macOS, and iOS projects are retained for future evaluation
but are not current production targets.

The canonical application and bundle identifier is `com.jce.pos`.

## Architecture foundation

- Feature-first clean architecture under `lib/features`
- Riverpod for dependency injection and state access
- GoRouter for centralized navigation
- Drift/SQLite dependencies for the Phase 1 local database
- Typed environment configuration through Dart defines
- Shared typed `Result<Success, Failure>` and failure categories
- Centralized application logging
- Injectable clock and UUID generation
- Recoverable Firebase initialization
- Firebase Authentication with offline-cached application access profiles
- Database-driven organization, branch, role, and permission context
- PostgreSQL Phase 2 schema and deployable Firebase callable functions
- Offline product catalog with normalized SKU, name, and barcode search
- Effective-dated organization and branch pricing stored in integer minor units
- Atomic product, category, and unit audit/outbox mutations
- Immutable inventory ledger with versioned branch/location balance projections
- Offline adjustments, compensating reversals, reorder signals, and stock counts
- Branch negative-stock policy and optional manager approval thresholds
- Device-assigned branch registers with recoverable offline cash shifts
- Immutable cash-in, cash-out, payout, and correction movements
- Payment-method close counts with discrepancy approval evidence and outbox writes
- Offline cart pricing with integer tax/discount calculations and split payments
- Atomic sale, inventory, receipt-sequence, audit, and outbox completion
- Snapshot-backed receipts and recent transaction history
- Migration-controlled PostgreSQL schema with branch-scoped remote commands
- Authenticated, idempotent product, inventory, shift, and sale transactions
- Generated typed SQL Connect change-feed and operation-result reads
- Retriable authenticated product-image finalization through Cloud Storage

## Environment configuration

JCE POS supports `development`, `staging`, and `production`. Configuration is
compiled into each build with `--dart-define`; service endpoints are never
stored as production constants in source.

Development example:

```sh
flutter run \
  --dart-define=JCE_ENV=development \
  --dart-define=JCE_ENABLE_DEMO_AUTH=true \
  --dart-define=JCE_DEMO_BRANCH_ID=demo-main
```

Production example:

```sh
flutter build windows \
  --dart-define=JCE_ENV=production
```

See [Environment configuration](docs/environment_configuration.md) for the
complete strategy and variables.

## Firebase

FlutterFire options are committed for the current Firebase project. The
canonical `com.jce.pos` Android and Apple apps are registered in `jce-pos`.
Regenerate configuration whenever Firebase apps or projects change:

```sh
flutterfire configure
```

Application startup is recoverable: initialization failures show a controlled
screen with retry instead of terminating before Flutter renders.

Phase 2 authentication uses the `getMyAccessProfile` and `registerDevice`
callables under `backend/functions`. Apply
`backend/sql/phase_2_access_control.sql`, configure the database secret, and
deploy the functions before enabling production sign-in. See
[Phase 2 access backend](docs/phase_2_access_backend.md).

Phase 4 adds the `inventory.adjustments.approve` permission. Apply
`backend/sql/phase_4_inventory_permissions.sql` to existing environments and
refresh the signed-in administrator's access before testing threshold approval.
Remote inventory tables and outbox processing remain part of Phases 7 and 8;
the running app uses Drift as its operational offline source in Phase 4.

Phase 5 adds `registers.manage` and `shifts.discrepancies.approve`. Apply
`backend/sql/phase_5_shift_permissions.sql` and refresh administrator access
before configuring registers. Cashiers continue to open and operate their own
shifts through `sales.process`. Register, shift, cash-movement, and close-count
mutations are atomic in Drift and enter the outbox; authoritative remote shift
tables and command processing remain part of Phases 7 and 8.

Phase 6 adds `sales.discounts.approve`. Apply
`backend/sql/phase_6_sales_permissions.sql` and refresh administrator access
before testing branch discount thresholds. Checkout re-resolves current local
product, price, tax, stock, and inventory-version data, then commits the sale,
payments, receipt sequence, inventory ledger, audit record, and outbox command
in one Drift transaction. Remote sale processing remains part of Phases 7 and
8.

Phase 7 adds the versioned authoritative PostgreSQL schema, transactional
`applyRemoteCommand` callable, generated SQL Connect SDK, secure change-feed
queries, permission-code seeds, and authenticated product-image finalization.
See [Phase 7 remote backend](docs/phase_7_remote_backend.md) before applying
migrations or deploying an environment. Development and staging are deployed
as separate Firebase/SQL Connect/Cloud SQL projects. The isolated production
project and runtime identity are prepared, but its live resources remain
blocked by the Cloud Billing project quota; never point it at a non-production
database.

Phase 8 adds the restartable synchronization engine, scoped outbox ownership,
atomic cursor advancement, optimistic master-data conflicts, accepted
inventory projections, foreground/background triggers, diagnostics, and the
administrator conflict workflow. See
[Phase 8 synchronization engine](docs/phase_8_sync_engine.md) before deploying
the updated Functions and client together.

## Code generation

```sh
dart run build_runner build --delete-conflicting-outputs --low-resources-mode
```

For continuous generation during development:

```sh
dart run build_runner watch --delete-conflicting-outputs --low-resources-mode
```

The checked-in Drift schema snapshot under `drift_schemas/` is the migration
baseline. Before changing a released schema, increment `schemaVersion` and run:

```sh
dart run drift_dev make-migrations
```

Web builds use the checked-in `web/sqlite3.wasm` runtime and generated Drift
worker. Regenerate the worker after upgrading Drift:

```sh
dart compile js web/drift_worker.dart -O4 -o web/drift_worker.js
```

## Verification

```sh
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test
cd backend/functions && npm run build
cd backend/functions && npm test
```

These checks also run in GitHub Actions.
