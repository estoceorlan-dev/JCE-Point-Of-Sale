# Phase 10 — Branch Stock Transfers

Phase 10 implements an offline-first, branch-aware transfer workflow from
draft through receipt and correction.

## Custody model

Stock is represented in exactly one explicit state:

- Before shipment, it remains on hand at the source. Approval reserves it in
  `inventory_balances.reserved_milli`.
- Shipment releases the reservation and posts a `transfer_shipment` ledger
  decrease at the source. The shipped quantity is then in transit.
- Receipt posts `transfer_receipt` ledger increases to the destination and,
  when applicable, its damaged location.
- Any shipped quantity not received or damaged remains in
  `discrepancy_quantity_milli` until an approved correction reconciles it.

The transfer item is the custody record for in-transit and discrepancy stock;
these quantities are never represented as an authoritative balance overwrite.

## State transitions

```text
draft → submitted → approved → shipped → received
                  ↘ rejected
draft/submitted/approved → cancelled
```

Transfers at or below a branch's optional approval threshold move from draft
to approved on submission. Higher quantities stop at submitted and require a
user with `transfers.approve` who is assigned to both branches.

Every transition uses optimistic version checks and a unique operation ID.
Retries return the existing result, while stale or invalid transitions fail
without partial inventory, audit, event, or outbox writes.

## Offline and synchronization behavior

Local mutations atomically write:

- The transfer or state update
- Transfer items and immutable event history
- Inventory ledger and balance projection changes when applicable
- A local audit log
- A serialized outbox command

Transfer changes use organization-wide change-feed entries so source and
destination devices can both project the workflow. Local outbox dependencies
serialize changes created on the same device; a destination-only device can
still upload a receipt after learning of shipment through the remote feed.

## Remote deployment

Apply `backend/sql/migrations/0005_phase10_stock_transfers.sql` before
deploying the updated Cloud Functions. The remote command service validates
all branch, location, product, state, approval, quantity, and inventory rules
again inside the PostgreSQL transaction.
