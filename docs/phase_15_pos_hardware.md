# Phase 15 POS hardware

Phase 15 isolates barcode scanners, receipt printers, and cash drawers behind
domain contracts. A completed sale never depends on hardware success: checkout
commits to SQLite first, then receipt delivery and the drawer pulse run as
separate best-effort operations.

## Supported hardware

- Keyboard-wedge barcode scanners that terminate scans with Enter, numpad
  Enter, or Tab.
- Network thermal printers that accept ESC/POS bytes over TCP (normally port
  9100), with 58 mm and 80 mm paper profiles.
- Cash drawers connected to an ESC/POS printer on drawer pin 2 or pin 5.
- Screen receipts and locally generated PDF receipts on every supported client.

USB- and Bluetooth-specific transports can be added behind `ReceiptPrinter`
without changing checkout or receipt templates. The current network adapter is
the supported physical-printer transport because it works without an internet
connection and does not require vendor-specific drivers.

## Camera scanning evaluation

Dedicated checkout registers use keyboard-wedge scanners: they are faster,
work offline, and do not require camera permission. Camera scanning is therefore
represented in the register configuration and `BarcodeScanner` abstraction but
is intentionally not activated for checkout. It should be implemented only for
a separately approved mobile inventory or low-volume fallback workflow, with a
camera permission and device-support review.

## Register configuration

Users with `registers.manage` configure hardware from **Administration → Registers
& Hardware**, or **POS → Register & shift → Hardware**. The administration route
does not require cashier sales permission. Configuration is branch- and register-scoped, version checked,
written atomically with local audit/outbox records, and synchronized through
`register.hardware.configure`.

Network ESC/POS settings require a host/IP, port, and paper width. Cash-drawer
support can only be enabled with that printer type. New and migrated registers
default to keyboard-wedge scanning, screen/PDF output, and a disabled drawer.

## Printing and retries

An original receipt is queued after the completed sale has been loaded from
SQLite. The local `receipt_print_jobs` table claims due jobs, records attempts,
and retries with bounded exponential backoff (2 seconds up to 5 minutes, five
attempts). Processing jobs are recovered after restart, and the foreground
lifecycle worker retries on resume and every 30 seconds.

Each explicit reprint renders `REPRINT - NOT ORIGINAL`, creates an append-only
local audit entry, and queues `receipt.reprint` for the remote
`receipt_reprint_events` history. A printer failure keeps the completed sale
unchanged and leaves screen/PDF output available.

## Cash-drawer authorization

The drawer use case requires `sales.process`, an active-branch sale with
`completed` status, and a positive applied cash payment. Non-cash, draft,
cross-branch, and unauthorized requests cannot call the drawer adapter.

## Deployment

1. Apply `backend/sql/migrations/0010_phase15_pos_hardware.sql`.
2. Build and deploy the Functions source so `register.hardware.configure` and
   `receipt.reprint` are accepted remotely.
3. Deploy the schema-version-13 Flutter client.
4. Assign the device to a register and configure the printer using its LAN
   address. Keep the printer and register on a protected branch network.
5. Complete a cash test sale, disconnect the printer for one retry test, then
   verify the marked reprint in local and remote audit history.

Run the Phase 15 coverage with:

```sh
flutter test test/features/hardware/phase_fifteen_pos_hardware_test.dart
flutter test test/core/database/migration_schema_test.dart
```
