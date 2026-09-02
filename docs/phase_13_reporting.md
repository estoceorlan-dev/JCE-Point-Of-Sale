# Phase 13 reporting definitions

## Data flow and scope

Transaction screens continue to write and observe SQLite. Dashboard and report
screens query the synchronized local database so they remain available offline.
Every local query requires an organization and one permitted branch. The
`LoadReportUseCase` validates the selected branch against the signed-in user's
assignments and `reports.view` permission before the repository is called.

PostgreSQL migration `0008_phase13_reporting_views.sql` supplies composable,
organization- and branch-keyed views for central reporting. Callers must always
filter both scope columns (or both source/destination branch columns for
transfers). The application does not query these views directly; normal sync
hydrates the operational SQLite source of truth.

## Metric definitions

- Daily branch sales: completed, partially returned, and returned sale totals,
  less completed corrections of type `return`, grouped by the branch-local
  calendar date. Voided and sync-rejected sales and corrections are excluded.
- Payment-method totals: applied payment amount less completed return refunds
  of the same method. Cash tender and change are not counted as revenue.
- Cashier performance: original sale totals and transaction count attributed to
  the sale cashier, less returns against those sales. Average ticket is net
  sales divided by original completed transaction count.
- Product sales: sold item quantity and total less completed returned item
  quantity and total.
- Gross profit estimate: net item revenue less snapshotted unit cost multiplied
  by net quantity. Intermediate quantity calculations use integer thousandths
  and round to the nearest minor unit. This is not an accounting profit figure.
- Inventory valuation: current on-hand quantity multiplied by the current
  weighted-average unit cost, rounded to the nearest minor unit.
- Low stock: `on_hand_milli - reserved_milli <= reorder_point_milli` per stock
  location.
- Inventory movement: immutable ledger entries in occurrence order. Reversal
  records remain visible.
- Shift reconciliation: counted cash less expected cash at shift close.
- Transfer performance: line quantity sums and elapsed minutes from shipment to
  receipt. Unreceived transfers have no lead time.
- Purchase/receiving performance: ordered value uses purchase-order unit cost;
  received cost uses goods-receipt landed unit cost. Remaining quantity excludes
  received and cancelled quantities.

All currency is integer minor units and quantities are integer thousandths.

## Filters, pagination, and exports

The UI exposes date, permitted branch, product, category, user, and payment
method filters. Filters that do not apply to a report model are harmless. Every
detailed local query is paginated; daily sales pagination occurs after
branch-timezone grouping. CSV and printable builders consume the exact filtered
dataset shown on the current page, so exported values cannot bypass scope or
filters.

## Refresh behavior

The PostgreSQL reporting objects are ordinary views, not materialized views.
They therefore need no refresh job and read committed transaction data. If
measured production volume later justifies materialization, refresh must occur
after a successful sync batch, use `REFRESH MATERIALIZED VIEW CONCURRENTLY`, and
publish its last successful refresh timestamp. Until then, stale materialized
data is deliberately avoided.
