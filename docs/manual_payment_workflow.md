# Manual cashier payment workflow

Decision: 2026-09-07. Printer/scanner models and payment-terminal provider remain
undecided. Continue with cashier-entered payments and optional hardware.
These client changes do not alter the database schema or implement a gateway.

## Cash

1. Build the cart using product search, manual barcode entry or the product list.
2. Open Take payment. Cash received starts empty; no money is assumed received.
3. Receive/count the cash, then enter it or use Exact cash/a cash preset.
   For split tenders, Exact cash fills only the balance after card/QR amounts.
4. Complete sale. The existing atomic checkout saves the sale, payments,
   inventory movements, audit and outbox locally. Give the displayed change.
5. The committed sale produces the receipt. A configured supported printer is
   attempted afterward. Otherwise use the screen receipt or Save PDF.

Handle the cash box/drawer manually. Leave automatic drawer opening disabled in
Registers & Hardware; this is already the default. Existing register settings
were not changed remotely by this implementation.

## Card or QR / E-wallet

1. Enter the intended card or QR / E-wallet amount in the POS payment form.
2. Manually key that same amount into the separate payment terminal/provider app.
   The POS does not currently transmit an amount, create a QR charge, poll a
   provider, or obtain an automatic approval result.
3. Check the merchant terminal/provider app for a successful payment of the
   correct amount. Do not confirm pending, declined or cancelled payments.
4. Record the transaction reference (required when branch policy says so).
   Never enter card numbers, PINs, security codes, passwords or tokens.
5. Tick the confirmation for each used non-cash method, then Complete sale.
   Editing that amount/reference clears its confirmation. This is a cashier
   attestation, not cryptographic proof or a provider authorization.

Cash/card/QR splits remain supported. Non-cash overpayment is rejected; only
cash can produce change. QR / E-wallet continues to use the existing e_wallet
payment code; no backend migration is required.

Payment inputs and cancellation are locked while checkout saves; repeated submit
cannot start a second checkout. A failed local save does not reverse an external
payment. If the terminal already approved it, do not charge again: keep the
reference, reconcile the existing payment, and resolve the sale with a supervisor.
Do not abandon a paid cart without reconciling/refunding externally as appropriate.
POS returns/voids also do not automatically refund a provider payment.

The payment dialog now keeps a visible reconciliation message after a confirmed
card/QR payment fails to save locally. Amount/reference edits do not clear that
message. References remain in the open form, and the POS does not automatically
retry or charge a provider. An explicit local-save retry is covered by a widget
test. This does not add durable payment-attempt storage: closing/restarting the
app can still lose unsaved form fields, and crash recovery remains an exit gate.

## Receipts and deferred integration

- Receipt content comes from the committed sale, including items, totals,
  recorded tender methods/amounts and cash change, not raw terminal/card data.
- Printer failure does not undo payment or inventory. Existing print retry,
  reprint and screen/PDF fallback behavior is retained.
- No printer is necessary for screen/PDF testing. Physical printing still needs
  a compatible printer and acceptance; PDF export alone does not send a job to
  a Windows printer.
- Scanning hardware is optional: use product search/manual entry while undecided.
- Automatic amount handoff requires a chosen provider/device, its supported API
  or protocol, credentials, and a separately scoped integration including
  idempotency, status recovery and refunds. No simulated approval is added.

Verification includes payment-form desktop/compact tests, short/overpayment,
cash change, per-method confirmation/reset, required references, split exact
cash, in-flight input/dismissal locks and duplicate-submit handling. Existing
hardware tests cover screen/PDF fallback, printer failure preserving the sale,
and disabled drawers receiving no pulse. Physical acceptance remains deferred,
not marked passed. This change does not itself deploy the updated client.

Local verification on 2026-09-07: all 242 Flutter tests passed, including eight
payment-form regressions and a new disabled-drawer check. The payment tests were
also rerun after the compact field layout adjustment.
Flutter analysis and formatting passed. The Windows staging Release bundle was
rebuilt with JCE_ENV=staging and JCE_ENABLE_DEMO_AUTH=false; run
`build/windows/x64/runner/Release/jce_pos.exe` with its adjacent DLLs/data intact.
It has not been installed on another device or physically accepted.

Phase 3 continuation on 2026-09-07: all 254 Flutter tests, analysis and formatting
passed, including the approved-external-payment/local-save-failure regression.
The Windows staging Release bundle was rebuilt successfully again with the same
environment defines. No client rollout or remote configuration change occurred.
