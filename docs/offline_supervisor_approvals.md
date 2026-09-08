# Offline supervisor approvals: contract and implementation gates

Updated 2026-09-07. **Contract foundation only; offline approval is unavailable.**
The default Riverpod service rejects both enrollment and approval on every
platform. A feature flag cannot enable it. Existing signed-in manager checks
remain in force; constructing an ApprovalGrant does not confer permission.

## Repository evidence

- No platform secure-storage or PIN cryptography dependency exists in pubspec.
- Existing approval_requests/approval_decisions support sale returns/voids;
  the request-type constraint does not support sale discounts. Decisions have
  no credential ID, device binding, or signed operation evidence.
- Checkout currently checks the signed-in actor's sales.discount.approve
  permission and records that actor and time. No typed supervisor-ID bypass is
  added. Other protected workflows retain their existing permission gates.
- The new core/approvals domain exposes ApprovalChallenge, ApprovalGrant and
  SupervisorApprovalService. Metadata checks cover scope, operation digest,
  requester, device, permission and time. They are not signature verification,
  credential validation, or replay protection.

## Enrollment design (not implemented)

1. Enroll online using a freshly authenticated supervisor session and the
   registered device. Server derives the internal approver ID, organization,
   active branch scope and allowed permission codes from current assignments.
   Never accept those grants from role names or a cashier-supplied approver ID.
2. Create a per-enrollment signing key on the device. Server signs a credential
   binding its public key, device registration, credential ID, approver,
   organization, explicit allowed branches/permissions, issue/not-before/expiry
   and key version. Default maximum validity is seven days; configuration can
   shorten it. No network is required for use during that bounded validity.
3. Require six ASCII digits for the local PIN. Encrypt the private key and
   server-signed credential using authenticated encryption and a salted,
   deliberately expensive PIN key derivation. Protect the envelope using the
   platform credential store and a device key. No raw PIN, private key or bearer
   credential may enter SQLite, outbox payloads, audit metadata or logs.
4. Select and validate crypto/platform adapters before implementation. A
   six-digit PIN has low entropy: key derivation alone cannot make a stolen
   envelope safe. Windows OS-account protection alone does not establish a
   hardware device binding. Verify key non-exportability/restore behavior and
   secure-store access on the intended Windows terminal. Unsupported platforms,
   including web without an accepted secure-store design, must fail closed.
5. Enrollment/PIN reset requires online reauthentication; revoke the replaced
   credential, preserve evidence needed for queued operations, and never reset
   attempt counters through offline reenrollment.

## PIN attempts and clock policy (not implemented)

Serialize attempts per device/credential in secure storage. Persist each failed
attempt before allowing another; five failures lock entry for 15 minutes.
Attempts during lockout do not invoke decryption or extend the window. Success
clears failures only after full credential validation. Restart must preserve
the lockout. Missing/corrupt attempt state fails closed until online enrollment.
Use trusted server time anchors plus elapsed-time checks; reject rollback or
unreliable clock state and require online refresh. Document that a fully
compromised OS can bypass local UI controls; server revalidation is mandatory.

## First workflow: sale discounts (not integrated)

Allocate stable sale/checkout operation IDs before approval. Freeze a canonical,
versioned operation snapshot containing organization, branch, register, shift,
device, cashier, sale/cart version, customer, ordered stable line IDs, product
and location IDs, milli-quantities, price/tax versions, integer money totals,
discount amounts/rules/reason, and applicable approval-policy version. Hash this
snapshot identically in Dart and on the server. Any relevant cart, policy,
context or price change requires a new challenge and supervisor review.

The challenge binds that digest, a unique challenge ID, permission, operation
type/ID, aggregate, requester/device and a short expiry. Display the significant
discount data to the supervisor. PIN unlock authorizes signing only this
challenge. A grant contains non-secret decision metadata; its effective expiry
is the earlier of the credential and challenge expiry. Credential signatures
and signed per-operation evidence remain in platform secure storage.

Transaction-specific binding and final execution checks follow the principles
in [OWASP transaction authorization](https://cheatsheetseries.owasp.org/cheatsheets/Transaction_Authorization_Cheat_Sheet.html).
PIN derivation must use an established password KDF with reviewed parameters;
see [OWASP password storage](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html).
These references guide the design; they do not certify this implementation.

## Atomicity, evidence delivery and replay (not implemented)

- Stage signed evidence securely before beginning checkout. In one SQLite
  transaction validate the frozen operation, claim the grant ID uniquely and
  insert sale, payments, ledger, audit, outbox and active-cart removal. Persist
  approver/credential IDs and evidence reference, never PINs or raw credentials.
- On transaction rollback retain the unchanged grant for an explicit retry
  within its validity. After a crash, recover a committed operation by its
  stable ID rather than allocate another sale or charge. Orphan secure evidence
  can be removed only after proving no committed/pending operation references it.
- The core sync module reads secure evidence by grant ID and attaches it only
  to the authenticated command request. Do not log request bodies or copy the
  credential into the persistent outbox. Missing evidence becomes an actionable
  conflict, not an auto-approval. Retain evidence until definitive server ack.
- Server verifies issuer/key/signature, credential scope/device, operation
  signature and recomputed digest, expiry, revocation and *current* approver and
  requesting-cashier authorization. Check expiry at approval time and sync time;
  credentials expired at synchronization require explicit conflict resolution.
- Within the server command transaction uniquely claim the grant, challenge and
  operation association. An identical retry returns the original outcome;
  reuse for another payload/operation fails. Receipt and inventory history of a
  locally committed sale remain intact if server approval is rejected. Resolve
  through audited reconciliation or compensating operations, never silently
  discard or rewrite a committed sale.

## Required next increments

1. Reviewed platform crypto/secure-store adapters, enrollment callable,
   credential registry/revocation and key rotation. Add new migrations; never
   rewrite deployed migration checksums. Deployment needs separate approval.
2. Persistent five-attempt/15-minute lockout, signed evidence staging, shared
   Dart/TypeScript canonicalization fixtures and negative crypto tests.
3. Schema migration for non-secret decision IDs/atomic claims, stable checkout
   identity, core sync evidence delivery and server replay checks.
4. Integrate only sale discounts first, with independent security tests for
   forged signature, wrong device/org/branch/permission/requester, modified
   operation, expiry/revocation, restart/rollback, duplicate/replayed grants,
   removed supervisor access, and existing foreign-organization denial.
5. Verify Windows secure storage physically; enable only the authorized pilot
   flag after acceptance. Expand to returns/voids, inventory, transfers,
   purchases and shift discrepancies afterward.

Local contract tests cannot substitute for any of these gates.

Verification on 2026-09-07: the full Flutter suite passed 254 tests; analysis
and formatting passed. Three approval contract tests cover all binding fields,
time boundaries/malformed metadata and rejecting service defaults. They do not
test crypto, PIN enrollment, persistent lockout, secure storage or replay claims,
which have not been implemented.
