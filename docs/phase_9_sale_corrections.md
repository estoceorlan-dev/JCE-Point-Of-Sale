# Phase 9 sale corrections

Phase 9 adds auditable returns and voids without changing the original sale,
sale items, or payments. Every correction is an offline-first compensating
transaction that atomically writes SQLite business rows, inventory and drawer
effects, an audit entry, and an outbox command.

## Local schema

- `sale_returns` stores the correction header, reason, amounts, approval link,
  inventory transaction, and immutable return/void number.
- `sale_return_items` stores returned quantities, prorated amounts, and the
  `restock`, `damaged`, or `non_restock` disposition.
- `refund_payments` supports cash, card, e-wallet, and store-credit refunds.
- `approval_requests` and `approval_decisions` retain manager approval
  evidence.
- Branch policy adds `return_approval_threshold_minor` and
  `void_window_minutes`.

The effective sale status is derived from completed correction rows. This
keeps the original sale header and financial snapshots immutable while still
showing completed, partially returned, returned, voided, and sync-rejected
states in Sales History.

## Rules

- Returned quantity is validated against all prior completed returns.
- Monetary components are prorated using integer arithmetic. The final return
  receives the exact remaining cents so full returns reconcile to the sale.
- Restock and damaged items post positive `sale_return` inventory ledger
  entries to an active destination of the correct type. Non-restock items do
  not affect inventory.
- Refund payments must exactly equal the correction total. Cash refunds require
  the current device's assigned register and open shift, and create a negative
  `cash_out` drawer movement.
- Voids reverse every remaining line and are rejected after any prior return.
  Voids outside the configured window require manager approval.
- Returns above the configured amount threshold require manager approval.
- Operation IDs make returns and voids idempotent.
- The first correction depends on the original sale operation, and every later
  correction depends on the preceding correction. This keeps server-side
  quantity and proration checks serialized even when several returns are
  created offline.
- A remotely rejected correction stays visible and blocks new corrections for
  that sale until its sync conflict is resolved. A later successful retry
  restores its completed status from the canonical change feed.

## Permissions

- `sales.returns.process` creates returns and voids.
- `sales.corrections.approve` approves threshold returns and late voids.
- `settings.manage` configures the branch correction policy.

Owner, admin, and manager roles receive both correction permissions. Cashiers
receive `sales.returns.process` only.

## Remote deployment order

1. Apply `backend/sql/migrations/0004_phase9_corrections.sql`.
2. Deploy the updated Cloud Functions.
3. Release the schema-version-8 client.

From `backend/functions`, migrations can be applied with `npm run db:migrate`
for a direct PostgreSQL URL or `npm run db:migrate:iam` for Cloud SQL automatic
IAM database authentication. See `PROVISIONING.md` for the required variables.

The remote handler independently reloads the original sale, serializes
concurrent corrections, recalculates quantities and prorated amounts, validates
destinations and refunds, enforces approval policy, and writes PostgreSQL
inventory/drawer effects in the same transaction as the correction.

## Verification

```text
flutter test test/features/pos/phase_nine_sale_corrections_test.dart
flutter test test/features/pos/sale_correction_dialog_test.dart
flutter test test/core/database/migration_schema_test.dart
cd backend/functions && npm test
```
