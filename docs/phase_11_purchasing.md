# Phase 11 — Purchasing and Receiving

Phase 11 separates procurement intent from physical stock custody. Supplier and
purchase-order changes are saved to Drift first, audited, and queued in the
outbox. Inventory changes only when an approved purchase order receives a goods
receipt.

## Local workflow

```text
Supplier
  ↓
Purchase order draft
  ↓
Submitted → Approved
  ↓
One or more goods receipts
  ↓
Inventory transaction + ledger + balance + weighted-average cost
```

Purchase orders track ordered, received, cancelled, and remaining quantities.
Partial receipts keep the order open as `partially_received`; the final receipt
moves it to `received`. Cancelling an order assigns its unreceived remainder to
the cancelled quantity without reversing stock already received.

## Costing decision

Weighted average is the initial inventory-costing method. Cost is projected per
branch stock location and product in `inventory_balances`. Every immutable goods
receipt item preserves:

- Received quantity
- Supplier unit cost
- Freight allocation
- Duty allocation
- Other landed-cost allocation
- Calculated landed unit cost
- Weighted-average unit cost immediately after posting

All amounts use integer centavos and quantities use integer thousandths. Division
uses deterministic round-half-up arithmetic. FIFO is deliberately deferred
until a business requirement justifies the additional layer tracking.

## Atomic receiving boundary

A receipt transaction writes all of the following or none of them:

- Goods receipt header and lines
- Purchase-order received quantities and status
- Inventory transaction and immutable ledger entries
- On-hand and weighted-average cost projections
- Local audit log
- Sync outbox command

The receipt operation ID is unique, so retrying the same command cannot increase
stock twice. Over-receipt is rejected against the current ordered remainder.

## Synchronization

Migration `0006_phase11_purchasing.sql` adds the authoritative PostgreSQL tables,
weighted-average projection, indexes, constraints, and purchasing permissions.
Remote command handlers validate scope and record versions, post inventory in
the same PostgreSQL transaction, and return supplier, order, receipt, inventory,
and cost projections for local convergence.

Offline outbox dependencies ensure a newly created supplier synchronizes before
an order that references it, and each order transition synchronizes after its
predecessor.

## Accounts payable boundary

`supplier_invoices` is not included. The roadmap makes it conditional on an
approved accounts-payable scope; goods receipts may retain a supplier document
number without creating an accounts-payable obligation.
