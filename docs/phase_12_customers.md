# Phase 12: Customer Management and Loyalty

Phase 12 adds organization-wide customer records without making checkout or
customer lookup depend on connectivity. PostgreSQL remains the online master,
while all screens read and write the local Drift projection first.

## Deployment

1. Apply `backend/sql/migrations/0007_phase12_customers.sql` after the Phase 11
   migration.
2. Assign the new permission codes to roles through the normal access
   provisioning workflow. The migration deliberately does not assign named
   roles:
   - `customers.view`
   - `customers.manage`
   - `customers.anonymize`
   - `loyalty.manage`
3. Deploy the updated callable Functions and SQL Connect schema.
4. Deploy the schema-version-11 client only after the backend migration is
   complete.

## Offline model

Customer creates and mutations commit the business data, audit entry, and
outbox command in one Drift transaction. Name, email, and phone normalization
supports local lookup. Contact duplicates are rejected by default. A user with
customer-management permission may explicitly acknowledge a legitimate
duplicate, or merge two active records.

Checkout remains valid with no customer. When an offline-created customer is
selected, the sale outbox operation depends on the customer-create operation,
so remote processing cannot race the new customer.

Purchase history is read from synchronized local sales in the active branch.
Customer records are organization-wide; operational notes remain branch-scoped.

## Merge rules

- The selected target record is authoritative for its name and existing
  contact fields.
- Missing target email or phone values are filled from the source.
- Addresses, branch notes, and historical sales move to the target.
- The source becomes `merged` and points to the target; it is not deleted.
- If only the source has a loyalty account, that account moves to the target.
- If both records have loyalty accounts, paired immutable `merge_out` and
  `merge_in` entries transfer the balance and the source account closes.

## Privacy lifecycle

Archival is reversible and preserves all history. Anonymization requires the
separate `customers.anonymize` permission and a recorded reason. It permanently
removes contact, birth-date, address, note, and marketing-consent data while
retaining the anonymous customer key on sales, audit logs, and financial
records. Anonymization is intentionally not reversible.

## Loyalty integrity

`loyalty_ledger_entries` is append-only in ordinary workflows. The account
balance is a projection updated in the same transaction as each entry.
Operation IDs are unique per organization, so a retried adjustment cannot post
points twice. Phase 12 provides manual, auditable adjustments and merge
transfers; earning and redemption policies can be layered on the ledger in a
later phase without rewriting history.

## Verification

```sh
flutter test test/features/customers
flutter test test/features/pos/phase_six_sales_test.dart
flutter test test/core/database/migration_schema_test.dart
flutter analyze
cd backend/functions
npm test
```
