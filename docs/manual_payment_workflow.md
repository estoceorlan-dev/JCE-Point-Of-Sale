# Manual cashier payment workflow

Decision: 2026-09-07. Printer/scanner models and payment-terminal provider remain
undecided. Continue with cashier-entered payments and optional hardware.
These client changes add device-local Drift schema 17 recovery fields. They do
not alter the remote schema, configure hardware, or implement a gateway.

## Cash

1. Build the cart using product search, manual barcode entry or the product list.
2. Open Take payment. Cash received starts empty; no money is assumed received.
3. Receive/count the cash, then type it, open the touch number pad from the
   amount field, or use Exact cash/a cash preset. The amount accepts only an
   unsigned value with up to two decimal places.
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
cannot start a second checkout. Before checkout, the active cart stores a stable
operation ID and the exact tender amounts/references. Cash-only failures reuse the
operation ID but allow the cashier to edit the cart before another attempt.

The cash field receives initial focus for keyboard entry. F9 completes a valid
payment and Esc cancels before saving. The touch number pad supports digits,
decimal, `00`, backspace, clear and Exact cash. After an externally approved
payment enters recovery, amount/reference edits and payment cancellation remain
locked so the cashier can only retry the saved local commit.

After a cashier confirms an externally approved card/QR payment, a failed local
sale save retains that checkout attempt in the device-local active cart. Restart
restores its amounts, references, confirmations, operation ID, and a prominent
do-not-charge-again message. Cart item, quantity, customer, discount, hold, and
clear actions stay locked until the same saved attempt commits. A changed retry
is rejected, corrupted tender data fails closed, and the POS never retries or
charges a provider automatically. Use Take payment for an explicit local-save
retry. If it cannot be completed, reconcile or refund the existing external
payment with a supervisor. POS returns/voids do not automatically refund it.

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
not marked passed. Staging deployment does not satisfy physical acceptance.

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

Phase 5 continuation on 2026-09-09 adds durable checkout-attempt recovery and
schema-16-to-17 migration coverage. The full Flutter suite, analysis, formatting,
and diff checks passed locally. No client build, rollout, remote schema, or
payment-provider configuration was changed by this increment.

Phase 6 continuation on 2026-09-09 adds the touch number pad, strict currency
input, payment focus/shortcuts, accurate terminal sync state, product-state retry
UI and compact/150%-text coverage. All 278 Flutter tests passed. Physical scanner
and printer acceptance remains pending. The schema-17 Windows staging bundle was
rebuilt with demo authentication disabled, and Android release `0d3joe7dkcmo8`
was uploaded to staging App Distribution without assigning a tester group. No
production environment, pilot feature flag or hardware setting was changed.
