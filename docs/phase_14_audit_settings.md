# Phase 14 audit and operational settings

## Offline-first configuration

Schema version 12 adds local `organization_settings`, `branch_settings`,
`number_sequences`, `reason_codes`, and `feature_flags` tables. Settings are
read from SQLite and therefore remain available when the remote backend is
unreachable.

Resolution is deterministic:

1. An active branch override wins.
2. The organization setting is used when no branch override exists.
3. A typed built-in default is used when neither record exists.

Removing a branch override immediately restores the organization or built-in
value. Existing branch policy columns remain maintained as local and remote
projections so inventory, sales, shifts, corrections, and transfers consume
the resolved policy without bypassing their repositories.

Supported operational keys cover tax treatment, negative stock, inventory and
transfer approval thresholds, receipt header/footer/width/tax display,
discount cap and approval threshold, shift rules, return approval, and the void
window. Receipt rendering, checkout tax mode, and maximum discounts read these
cached values directly. Inventory-adjustment forms use active effective reason
codes and enforce required notes.

## Audit guarantees

Local and remote audit records are append-only. SQLite and PostgreSQL install
triggers that reject update and delete attempts. Each synchronized mutation
shares its operation ID between the local audit row, outbox command, processed
remote operation, change-feed entry, and remote audit row.

Audit records capture organization, branch, actor, device, action, entity,
operation, and UTC timestamp. Device identity is read from local metadata and
sent separately from the business payload. Metadata passes through a recursive
allow-safe sanitizer that redacts password, secret, token, authorization,
credential, payment-card, CVV, and PIN-like fields, bounds collection depth and
size, and truncates long strings. Settings, reason-code, and feature-flag
changes record safe before/after values.

The audit page is permission-gated by `audit_logs.view` and filters the local
cache by permitted branch, action, actor, date, entity, ID, or operation. An
organization-wide event is visible from each permitted branch, while events
from other branches are excluded.

## Remote deployment

Apply `backend/sql/migrations/0009_phase14_audit_settings.sql` before deploying
the updated callable Functions and schema-version-12 clients. The migration
adds the remote configuration tables, audit device identity and indexes, plus
append-only audit triggers. Settings commands require `settings.manage`, use
optimistic versions, and run the business write, audit insert, change-feed
insert, and processed-operation insert in one PostgreSQL transaction.

Deploy the updated SQL Connect schema after the PostgreSQL migration. Existing
clients must not send Phase 14 commands until the migration and Functions are
live.
