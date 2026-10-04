# Production client threat model

Status: technical baseline complete; security and release-owner approval pending  
Scope: Android POS/operations and web administration fallback  
Excluded: production Windows, iOS, macOS, and Linux

## Assets and trust boundaries

Protected assets include Firebase identity tokens, organization/branch/register
assignments, local business projections, pending outbox commands, sales and
payments, customer/employee data, inventory, audit evidence, product images, and
cloud spend capacity.

The Android or web client is never an authorization boundary. It may request an
operation, but callable Functions and PostgreSQL rules must revalidate identity,
active organization, branch scope, permission, record ownership, input limits,
idempotency, and current server state. SQLite and browser storage are untrusted
projections and queues, not the online source of truth.

## Approved authentication and device-trust paths

| Client | Authentication | Device/application signal | Production scope | Failure behavior |
| --- | --- | --- | --- | --- |
| Android | Firebase Authentication token sent through the supported Functions SDK | Play Integrity through Firebase App Check, introduced and enforced in Phase 3 | POS and approved operations | Missing/invalid Auth or enforced App Check is denied server-side; missing or mismatched production config stops startup |
| Web | Firebase Authentication token sent through the supported web SDK | reCAPTCHA Enterprise through Firebase App Check, introduced and enforced in Phase 3 | Administration and operational fallback only | Direct POS access redirects; missing/invalid Auth or enforced App Check is denied server-side |
| Windows | No approved production path | None approved | Not shipped | Startup and release validation fail closed under ADR-0001 |

App Check is an abuse signal, not user authorization. Phase 3 must first observe
metrics, validate legitimate client coverage, and then enforce it. Server RBAC,
input validation, quotas, idempotency, and rate/cost controls remain mandatory.

## Threats and required controls

| Threat | Existing Phase 0–2 control | Remaining release gate |
| --- | --- | --- |
| Development/staging binary reaches production, or production reaches the wrong project | Explicit protected-build environment, visible non-production banner, independent approved-project comparison, separate Hosting targets | CI provenance and signed artifact checks in Phase 9 |
| Tampered client changes tenant, branch, price, quantity, approval, or payment data | Server-side identity/RBAC/business validation and negative tests remain authoritative | Live cross-tenant and tampering tests in Phases 4 and 10 |
| Captured command is replayed or duplicated after reconnect | Stable operation IDs and server idempotency exist | Multi-device/fault rehearsal and retention sizing in Phases 5 and 10 |
| Stolen token or shared browser/Android profile exposes data | Short-lived provider tokens; access refresh/offline-age controls; web POS disabled | Secure token/local-data storage, managed-device policy, sign-out cache clearing, and revocation rehearsal in Phases 3 and 6 |
| Automated or modified clients exhaust Functions, database, Storage, or paid services | Page/upload caps and fail-closed access exist | App Check, per-identity/device/IP rate limits, quotas, concurrency caps, budgets, and abuse tests in Phases 3–4 |
| Network interception or endpoint substitution | Firebase SDK TLS and production project validation; optional custom API URL must be HTTPS | Approved certificate/network boundary and device time behavior tests |
| Offline role revocation is delayed | Cached access has a configured maximum age and refresh path | Business-approved offline age, high-risk offline restrictions, and revocation tests in Phase 3 |
| Local SQLite/browser data is copied or modified | Remote server never trusts it as authority; web POS disabled | Android encryption or managed-device compensating control; web cache minimization/clearing in Phase 6 |
| Shared client secret is extracted | No shared API secret or service-account credential is added to clients | Secret scanning and artifact inspection in Phase 9 |
| Unsupported Windows Firebase path is promoted | ADR-0001, startup gate, and release validator reject Windows production | A superseding ADR, device-proof design, implementation, and shared transport contract tests |

## Security invariants

- Client-side route hiding never grants or proves permission.
- Organization, branch, role, category, project, and endpoint identifiers remain
  configuration/data, not privileged source constants.
- Production client configuration contains public Firebase identifiers only.
- No database password, service-account JSON, signing key, shared API secret, or
  customer data is compiled into an artifact.
- Offline writes commit business data, audit evidence, and outbox intent together.
- A failed sync never deletes the only local copy of an unacknowledged operation.
- Revocation and server authorization win over stale client state whenever the
  server can be reached.

## Acceptance still required

Security and release owners must approve this model after Phase 3–6 controls and
tests produce evidence. Any new platform, direct HTTPS transport, payment
processor, analytics/crash SDK, or background service changes the trust boundary
and requires an update before release.
