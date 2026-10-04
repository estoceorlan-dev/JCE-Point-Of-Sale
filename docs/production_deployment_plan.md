# JCE POS deployment, testing, and production-readiness plan

Status: Technical foundation deployed; Phases 3 and 4 in progress; security, sync, recovery, and device-acceptance gates remain; no real/customer data authorized  
Baseline date: 2026-09-16  
Latest technical verification: 2026-09-20  
Production scope: Android POS/operations and web administration fallback; Windows deferred by ADR-0001  
Architecture: Flutter + Riverpod + Drift/SQLite + Firebase Authentication/Functions/Storage + PostgreSQL/SQL Connect

## Purpose and release standard

This plan turns the existing staging implementation into a controlled, supportable
production service. It covers environment isolation, usability, correctness,
offline synchronization, access control, abuse and cost controls, performance,
observability, deployment, rollback, and ongoing operations.

No test program can prove that software has zero defects or is absolutely secure.
For this accelerated release, "secure" means the measurable technical controls in
this plan are enabled and tested, there are no known Severity 0/1 or critical/high
security defects, and financial/synchronization invariants pass live testing.

This document does not authorize production data changes. Each production change
requires the approvals and evidence identified in its phase.

## Accelerated production goal and scope

Goal: make the Android POS and web administration system operational in the
isolated production environment as quickly as possible without weakening runtime
security, transaction correctness, offline sync, recovery, or cost controls.

The release follows a technical critical path. Work may move between phases when
dependencies permit, but every mandatory technical gate must pass before real
production/customer data is accepted.

| Mandatory for launch | Explicitly deferred from the launch critical path |
| --- | --- |
| Production signing and fail-closed configuration | Naming backup personnel for each role |
| Firebase Auth, unique user identities, RBAC, and least-privilege IAM/database grants | Windows and other legacy-platform compatibility |
| Android/web App Check registration and enforcement | Historical-record cleanup and legacy-document reconciliation |
| Durable per-identity rate limits plus Functions instance/concurrency/cost caps | Formal filing, expanded governance paperwork, and nonessential narrative documentation |
| PostgreSQL migrations, SQL Connect contract, Storage rules, Functions, and Hosting deployment | New features and cosmetic work unrelated to launch usability |
| Automated technical backups, PITR, deletion protection, restore verification, and rollback artifacts | Additional personnel assignments beyond the already named primary operators/tester |
| Unit/widget/backend/integration, sync-fault, security-negative, performance, and live smoke tests |  |
| Monitoring, alerts, reconciliation, and controlled pilot rollout |  |

Deferral applies only to assignments and paperwork. It does not defer technical
backups, restore capability, audit logs, release signing, security enforcement,
testing, monitoring, or rollback. Minimal machine-verifiable release evidence
(build identifiers, checksums, test output, migration state, and deployed revision
IDs) remains required; no additional prose or filing is required for launch.

### Accelerated execution order

1. Finish production configuration, signing, IAM/database users, Storage, and
   protected Cloud SQL settings.
2. Enable App Check, server authorization, durable rate limits, runtime caps,
   secure upload validation, and secret-safe configuration.
3. Apply migrations and least-privilege grants; deploy SQL Connect, Functions,
   Storage rules, and Hosting.
4. Run the complete automated suite, release builds, sync/fault/security tests,
   performance checks, and backup/restore verification.
5. Run live production preflight and smoke tests with synthetic data only.
6. Promote the signed release to the named two-branch pilot only after all
   mandatory technical gates pass.

## Current verified baseline

The following records the 2026-09-16 baseline with dated verification updates.

| Area | Evidence | Current status |
| --- | --- | --- |
| Flutter formatting | `dart format --output=none --set-exit-if-changed lib test tool` checked 651 files on 2026-09-20 | Pass; 0 changed |
| Flutter static analysis | `flutter analyze` | Pass; no issues |
| Flutter automated tests | `flutter test` on 2026-09-20 | Pass; 344 tests passed, 1 opt-in performance test skipped |
| Backend verification | `npm run lint` and `npm test` on 2026-09-20 | Pass; security/type checks and 94 tests passed |
| Test inventory | 71 Dart test files and 19 TypeScript test files, plus script tests | Good unit/widget/backend base |
| Integration tests | 22 synthetic local PostgreSQL manager-grant checks passed against all 16 migrations; production denial checks passed with a temporary verified Auth identity and App Check debug token on 2026-09-20; both were deleted and absence verified | Genuine Android/web attestation, multi-device sync and physical-device E2E remain unverified launch gates |
| Performance | Opt-in 10,000-product file-backed benchmark rerun on 2026-09-18: barcode worst 12.5 ms, text search worst 12.3 ms, checkout commit 67.8 ms | Local targets pass; representative Android/web hardware and endurance evidence remain required |
| Local database | Drift schema version 19 with released-schema migration tests | Implemented; device migration rehearsal still required |
| Remote database | Migrations `0001` through `0016` exist | Applied and checksum/ownership/grant verified through `0016` in production |
| Offline sync | Atomic outbox, idempotent operation IDs, retry state, cursors, tombstones, conflicts, bootstrap, and tests exist | Strong baseline; live multi-device/fault testing remains |
| Authorization | Database-driven organization/branch/role/permission checks and negative tests exist | Strong baseline; live race and cross-tenant tests remain |
| Production environment | Isolated project, Auth, Hosting, Storage, Functions, SQL Connect, Cloud SQL, client registrations, billing, and budget are live | Pass; no real/customer records have been admitted |
| Build safety | Profile/release builds require explicit non-development `JCE_ENV`; production rejects demo auth and diagnostics | Implemented and tested |
| Production preflight | Read-only project/resource/IAM check | Pass with zero failures; automated and on-demand backups are successful |
| Android signing | Dedicated 4096-bit RSA production key; release signing fails closed when key configuration is absent | Signed `1.0.0+2` AAB verified on 2026-09-20; signer matches preserved `1.0.0+1`; not installed or distributed to pilot devices |
| Windows distribution | No production installer/update signing workflow is present | Deferred; not a blocker because Windows is outside this release scope |
| Windows Firebase support | ADR-0001 defers production Windows and the app fails closed there | Implemented safety gate; no Windows artifact will ship |
| Function abuse controls | Auth/RBAC, verified-email checks, page caps, enforced App Check, durable per-identity rate limiting, and runtime caps | Deployed; 12 functions are bounded to one instance each and unauthenticated calls are rejected |
| Storage controls | Owner-scoped staging, deny-by-default canonical paths, 5 MiB/type limits, server revalidation, uniform access, and public-access prevention | Deployed with App Check enforced |
| Dependency security | Production `npm audit --omit=dev` after the compatible lockfile update | Pass; 0 vulnerabilities, with backend lint/type checks and all 70 tests still green |
| Monitoring | Central logs, budget alerts, SQL CPU/disk alerts, and production HTTP 5xx alerting route to the approved email | Core pilot alerting active; client crash telemetry and expanded dashboards remain later hardening |
| Local data protection | Android 10+ app sandbox/device encryption is the approved initial boundary; web is administration-only and Windows production fails closed | App-level SQLite encryption remains future defense-in-depth and requires device-policy acceptance during UAT |

Existing detailed evidence should remain linked to, rather than duplicated from:

- [SQL Connect infrastructure-only trial record](sql_connect_trial_record.md)
- [Staging acceptance checkpoint](staging_acceptance_checkpoint.md)
- [Synchronization engine](phase_8_sync_engine.md)
- [Admin/POS completion status](admin_pos_completion_status.md)
- [Environment configuration](environment_configuration.md)
- [Offline supervisor approval design](offline_supervisor_approvals.md)
- [POS hardware validation](phase_15_pos_hardware.md)

## Production success targets

Approve or adjust these targets in Phase 0. They are release gates after approval.

| Category | Initial target |
| --- | --- |
| Financial correctness | No duplicated or missing sale, payment, refund, cash movement, receipt number, or inventory ledger entry in acceptance and reconciliation tests |
| Offline operation | Product lookup, cart, cash sale, receipt fallback, shift-safe actions, and outbox persistence continue through a 72-hour network outage on supported POS devices |
| Sync integrity | At-least-once delivery with server idempotency; no silent discard; every permanent failure/conflict is visible and actionable |
| Sync freshness | When online, 99% of ordinary operations reach the server within 2 minutes; alert when the oldest eligible outbox item exceeds 10 minutes |
| Local performance | Preserve current benchmark gates: barcode lookup <200 ms, text search <500 ms, local checkout commit <1,000 ms with at least 10,000 products |
| UI responsiveness | No sustained UI blocking during import, bootstrap, sync, report generation, image handling, or printing; long work has progress and cancel/retry behavior where safe |
| Backend reliability | Monthly callable availability target of 99.9%, excluding declared maintenance; the POS remains locally usable during a backend outage |
| Recovery | Proposed server RPO <=5 minutes using PostgreSQL PITR and RTO <=4 hours; unsynced device transactions remain recoverable from the local outbox |
| Security | No unresolved critical/high dependency or penetration-test finding; no cross-organization or unauthorized cross-branch access |
| Accessibility/usability | Keyboard, touch, scanner, large-text, contrast, error recovery, and cashier task acceptance pass on the supported device matrix |

## Roles and required evidence

One person may fill more than one role, but the release approver must not be the
only tester of the release candidate.

| Role | Responsibility |
| --- | --- |
| Release manager | Gate tracking, change freeze, approvals, artifact promotion, rollback decision |
| Client owner | Flutter, local database, offline behavior, platform builds, signing, updates |
| Backend/data owner | PostgreSQL, migrations, Functions, SQL Connect, backups, reconciliation |
| Security owner | Threat model, IAM/RBAC, device trust, secret handling, abuse testing, incident review |
| QA owner | Test matrix, defect triage, regression evidence, performance and accessibility |
| Branch operations owner | Hardware, cashier/manager UAT, training, pilot acceptance, continuity procedure |
| Finance/billing owner | Budgets, quotas, spend caps, forecast review, emergency cost action |

Nominated primaries: Orlandone Estoce (release, client, backend/data, security), Efren
Melencion (QA), and Julie Rose Estoce (branch operations and finance/billing).
The privacy/legal approver and named backup personnel remain unassigned. Under the
accelerated scope, those assignments and related paperwork are deferred and are
not technical launch gates. The named primary operators and independent QA tester
remain responsible for the pilot release.

For every checkbox, attach evidence to the release record: commit SHA, environment,
command or test case, timestamp, operator, result, artifact digest, and any defect
or exception link. Never include credentials, access tokens, customer data, or
private keys in the evidence.

## Phase 0 — Scope, risk, ownership, and release policy

Objective: make the production boundary and decision authority explicit before
infrastructure or application changes.

- [x] Record the primary operators and independent QA tester. Naming backup
  personnel is explicitly deferred until after the pilot and does not block the
  technical release.
- [x] Confirm the initial supported production platforms and minimum versions:
  Android 10+ and the latest two stable Chrome/Edge major versions; Windows is
  deferred and pilot hardware/browser acceptance remains a later gate.
- [x] Decide whether Windows POS can ship in the first production release. Record
  the decision in an architecture decision record; see Phase 1.
- [x] Classify data: authentication data, employee data, customer PII, sales,
  payments, inventory, audit evidence, logs, backups, and local caches.
- [ ] Keep collection of optional customer/employee PII disabled or minimized until
  retention, deletion, legal/tax record, privacy, and audit-access policies are
  approved. Formal policy paperwork is deferred from the technical launch path.
- [ ] Approve Severity 0–3 definitions, triage response times, change windows,
  maintenance communication, and rollback authority.
- [ ] Approve the production SLO/RPO/RTO targets in this document.
- [x] Define the pilot branches through deployment configuration; do not hardcode
  branch or role IDs.
- [ ] Freeze new feature work after the release-candidate cut. Only reviewed
  release blockers may enter the candidate branch.
- [ ] Inventory the local `C:/JCE/credentials.md` without copying its contents.
  Move any active secrets to an approved password/secret manager, rotate exposed
  values, and remove plaintext copies when recovery is confirmed.
- [x] Stop further legacy-record cleanup for this release. The executable release
  baseline is remote migrations through `0016` and local schema 19.

Exit gate:

- [ ] The named primary release/security/backend owner and independent QA tester
  accept the technical scope and release freeze. Backup-person assignments and
  nonessential filing are not blockers.

## Phase 1 — Production platform architecture

Objective: ensure every production client uses a vendor-supported security and
network path.

- [x] Re-check Firebase's production support matrix at release time. Current
  official guidance warns that Firebase on Windows is not intended for production.
- [x] Choose and document one Windows path:
  - defer Windows production and launch only approved supported platforms; or
  - implement a supported HTTPS/API client for Windows using the existing domain
    repository contracts, Firebase/Identity Platform token verification on the
    server, and per-installation asymmetric device credentials protected by the
    Windows TPM/CNG where available; or
  - obtain written vendor/support and security approval for another supported
    architecture.
- [x] Do not embed a shared API secret in the desktop binary. Device proof must be
  unique, revocable, rotated, scoped to an organization/branch/register, and safe
  against replay with nonce/timestamp/request-digest verification.
- [x] Define the Android attestation provider and the web reCAPTCHA Enterprise
  provider for Firebase App Check.
- [x] Define the web scope. Because browser storage is user-accessible, restrict
  sensitive offline data, clear cached identity/business data on sign-out, and
  do not treat web as a hardware-capable offline POS unless separately accepted.
- [x] Preserve clean architecture: platform authentication, device attestation,
  and transport implementations stay in Data; Domain remains Flutter/Firebase
  independent.
- [x] Record shared transport contract tests as a required ADR-0001 supersession
  condition. They are not applicable to this release because Windows production
  is deferred and no alternate Windows transport is shipped.

Exit gate:

- [ ] Each shipping platform has an approved support statement, threat model,
  authentication path, device-trust path, and tested failure behavior.

## Phase 2 — Isolated production infrastructure and configuration

Objective: provision production without any dependency on development or staging.

- [x] Link the approved production Cloud Billing account and configure the
  project-scoped budget and alert channel. The billing account uses USD, so the
  PHP 1,000 ceiling is represented conservatively by USD 15.
- [x] Confirm service quotas and SQL Connect trial eligibility immediately before
  provisioning. The trial metric was unused before provisioning and returned `1`
  afterward.
- [x] Record a zonal Cloud SQL pilot and a maximum PHP 1,000 monthly budget. This
  is a cost envelope, not evidence that the database fits it; pricing must be
  reviewed after the billing account currency and exact tier are known.
- [x] Start the authorized infrastructure-only SQL Connect trial with an empty
  service, default Cloud SQL instance, and logical database. The authorized
  hardening pass subsequently deployed schema/connector contracts, migrations,
  and least-privilege runtime access; no real/customer data was deployed. See the
  [trial record](sql_connect_trial_record.md).
- [x] Provision the production Firebase/Google Cloud project, PostgreSQL/SQL
  Connect instance, Storage bucket, Hosting site, runtime service account, and
  deployment identities in `asia-southeast1`.
- [x] Use separate production Auth users, service identities, database, bucket,
  Hosting target, monitoring project, and CI environment. Never reuse staging data
  or credentials.
- [x] Register isolated production Android/web Firebase apps, generate gitignored
  client options, validate them against the approved project, and compile both
  clients. Storage use remains unavailable until the real bucket exists.
- [x] Add distinct staging and production Hosting target mappings in
  `firebase.json` and `.firebaserc`; production Hosting is deployed with hardened
  browser and cache headers.
- [x] Make `JCE_ENV` mandatory for every release/profile build. A release must fail
  during CI/startup if it is missing, `development`, demo auth is enabled, or the
  selected Firebase project does not match the allowed project ID.
- [x] Add a build-time environment banner/watermark for development and staging;
  production must have no demo authentication or diagnostic data leakage.
- [x] Store deployment parameters as environment configuration, and secrets in
  Secret Manager/CI protected secrets. Use workload identity federation/OIDC
  instead of long-lived service-account JSON where supported.
  Tag-only GitHub OIDC is active for the exact repository; automated promotion
  remains a Phase 9 release-process improvement and is not used to bypass the
  verified manual deployment boundary.
- [x] Keep the Functions runtime service account least-privileged. Separate deploy,
  migration, runtime, backup, support, and billing roles.
- [x] Use Cloud SQL IAM authentication through the supported connector. The runtime
  service account has only Cloud SQL client/instance-user and log-writer roles;
  the database runtime role cannot read migration history or create schemas.
- [x] Enable automated backups, point-in-time recovery, deletion protection,
  maintenance windows, auto-resize with a 20 GB ceiling, and storage-growth alerts.
  Both automated and on-demand production backups completed successfully. A
  separate long-term archive is deferred while production contains no customer data.
- [x] Apply infrastructure labels for environment, owner, system, data class, and
  cost center. Google Cloud-safe values are `owner=jce-pos-project` and
  `cost_center=jce-pos-pilot`.
- [x] Pin the production region and verify that Auth, Functions, SQL Connect,
  database, Storage, and users have acceptable latency and data-residency behavior.

Exit gate:

- [x] A production preflight proves project isolation, correct identities, no
  plaintext database password, backup/PITR readiness, and fail-closed client config.

## Phase 3 — Security, authorization, device, and local-data hardening

Objective: prevent unauthorized access even when a client is modified, offline,
stolen, or connected to the wrong branch.

### Implemented checkpoint — manager register approvals

- [x] Apply production App Check to the isolated manager Firebase session before
  authentication. Web manager sessions use in-memory persistence; cleanup attempts
  app deletion even when sign-out fails, without changing the cashier session.
- [x] Require verified email and server-validated credential authentication within
  five minutes when issuing a register-resolution grant. Token refresh alone does
  not count as reauthentication. This does not yet cover every sensitive action.
- [x] Recheck the manager's active organization, branch, user, role, assignment, and
  `registers.manage` permission at grant validation and consumption. Serialize grant
  issuance/use with application role/user mutations; retain action bindings, expiry,
  single consumption, and operation-ID retry behavior.
- [x] Deploy `1.0.0+2` web and the two affected Functions; build and verify the signed
  Android AAB. Live unassigned-identity denial checks passed on 2026-09-20 with no
  business writes. The temporary Auth identity and App Check debug token were removed
  and their absence verified. Debug-token testing is not genuine device attestation.

Minimal release evidence:

- Android (now preserved): `build/releases/1.0.0+2/app-release.aab`, SHA-256
  `ED8A12A87A2C90BAC62766A5021706FC7B9320CD14CF6CECF34FB8B4AC497441`.
- Previous Android artifact preserved at `build/releases/1.0.0+1/app-release.aab`.
- Web at this checkpoint: production Hosting reported `1.0.0+2`; `main.dart.js` SHA-256
  `C69522C28E188923FCB42E17BA856624FC918FB1CC40C4F1B559A96F3CFF79D5`.
- Functions: `authorizeregisterclaimresolution-00003-fol` and
  `applyremotecommand-00003-gix`, both ACTIVE with max instances 1 and concurrency 10.
- Regression checks: 338 Flutter tests passed (1 opt-in performance test skipped),
  clean Flutter analysis, 80 backend tests passed, and 22 local PostgreSQL checks.
  The database regression is repeatable with `npm run test:manager-grants:postgres`
  and an explicit loopback-only `JCE_SECURITY_TEST_DATABASE_URL` pointing at the
  dedicated `jce_security_test` database.

Next: implement shared-terminal inactivity locking that preserves unsynced work,
then privileged-account MFA/reauthentication and account-lifecycle tests. Phase 3
is not complete; the remaining checks below and later technical gates still apply.

### Identity and sessions

- [x] Require verified email where the workflow claims verified identity; validate
  the Firebase token's verification state on the server.
- [ ] Require MFA for organization-wide administrators, support operators,
  migration operators, and break-glass accounts.
- [ ] Prohibit shared administrator accounts. Give every cashier/manager a unique,
  auditable identity.
- [ ] Add inactivity locking suitable for a shared POS terminal. Reauthentication
  must be required for sensitive manager/admin actions.
- [ ] Test password reset, invitation mismatch/expiry/reactivation/regeneration,
  disablement, refresh-token revocation, device loss, and account recovery.
- [ ] Keep at least two active full administrators, while preventing self-lockout
  and concurrent last-administrator removal.

### Application authorization

- [x] Treat server-side permissions as authoritative. UI hiding is usability, not
  security.
- [ ] Verify every read and mutation against active organization, branch assignment,
  role state, permission code, record ownership, and operation context inside the
  database transaction.
- [x] Keep permission grants database-driven; migrations may seed permission codes
  but must not grant privileges based on role names.
- [ ] Complete live negative tests for foreign organizations, unauthorized branches,
  stale access profiles, archived branches, suspended users, unassigned devices,
  concurrent archival, and last-admin races.
- [ ] Separate organization-wide administration permissions from branch operating
  permissions and review the effective-access matrix with the business owner.
- [ ] Limit support access to time-bound, ticket-linked, audited elevation. Define
  a tested break-glass procedure and alert on its use.

### Offline access and approvals

- [ ] Replace the single global offline-access age with configurable risk-based
  policies if required: shorter for administration, longer for essential cashier
  operation, and an explicit absolute emergency maximum.
- [ ] On access expiry or known revocation, deny sensitive actions while preserving
  local records needed for reconciliation and support.
- [ ] Keep offline supervisor approvals disabled and fail-closed unless the full
  design in `offline_supervisor_approvals.md` is implemented: secure enrollment,
  encrypted device-bound credentials, signed per-operation evidence, expiry,
  revocation, persistent lockout, server replay protection, and current-permission
  verification.
- [ ] Never substitute a typed approver ID or plaintext local PIN for cryptographic
  approval evidence. The existing signed-in manager authorization remains the only
  permitted fallback until the secure workflow passes acceptance.

### App, API, storage, and database hardening

- [x] Initialize production App Check, including temporary manager sessions, and
  enforce it on callable Functions and configured Firebase services. Synthetic
  Auth → App Check debug token → Function → Cloud SQL denial checks pass.
- [ ] Verify genuine Play Integrity and web reCAPTCHA Enterprise attestation,
  rejected-token behavior, and verification metrics on supported pilot clients.
- [ ] Use App Check token consumption/replay protection for rare high-risk calls
  such as device enrollment, invitation generation, and manager grants after
  measuring latency and cost. Keep operation-ID idempotency for all mutations.
- [x] Keep Windows production fail-closed and outside the release. Its alternate
  transport/device-proof work is deferred and cannot be enabled accidentally.
- [ ] Define strict request schemas, reject unknown or oversized fields, cap string,
  list, batch, page, report-range, and import sizes, and return stable safe errors.
- [x] Preserve the existing 1–500 bootstrap/change-feed page bounds and add tests
  that boundaries cannot be bypassed by type coercion or malformed numbers.
- [ ] Restrict image uploads to approved MIME types and verified file signatures,
  strip metadata, scan/transform server-side, cap dimensions and decoded size, and
  delete abandoned staging images automatically.
- [ ] Review Storage download-token lifetime/revocation and avoid public canonical
  product objects. Add App Check without weakening current UID/path rules.
- [x] Use parameterized SQL only, least-privilege database grants, transaction
  timeouts, statement timeouts, lock timeouts, and audit-safe redaction.
- [ ] Encrypt sensitive local data using the approved Android design and Keystore;
  never place keys in Dart defines, logs, source, or the database directory.
- [ ] If full database encryption cannot be approved for a platform, require OS
  full-disk encryption, managed-device policy, restricted OS accounts, remote wipe,
  and a documented residual-risk acceptance before pilot use.
- [ ] Define local-cache retention and secure erase behavior for sign-out, user
  change, branch reassignment, lost devices, and decommissioning without deleting
  unsynced business records prematurely.

Exit gate:

- [ ] Threat-model review and security tests show no auth bypass, cross-tenant leak,
  insecure local secret, unrestricted upload, or unsupported client trust path.

## Phase 4 — Abuse prevention, usage limits, and cost containment

Objective: bound paid-resource consumption without preventing normal POS work.

### Implemented checkpoint — 2026-09-20

- [x] Add atomic UID and authorized-organization quotas to all 12 callables, with
  validated operator-only `JCE_USAGE_LIMITS_JSON` overrides and no role exemptions.
  Rotating client device IDs cannot bypass the global UID ceiling; foreign callers
  cannot charge another organization's shared bucket. Exact endpoint RBAC still applies.
- [x] Separate new-installation daily limits from device heartbeat limits; a disabled
  device cannot re-register to remove its disablement.
- [x] Route new image bytes through the authorized callable before any Storage write:
  5 MiB/image, PNG/JPEG/WebP signatures, atomic 100 MiB/day/organization upload-attempt
  budget, collision-safe staging, and image-function concurrency 1. Direct client
  staging uploads are denied by the new Storage rules. Full decoding/metadata stripping,
  cumulative stored-byte quotas and protected download/egress limits remain open.
- [x] Bound administration and stock-location snapshots: default 5,000 rows/collection
  and 2 MiB total response; fail explicitly rather than silently truncating records.
- [x] Persist sync cooldowns with server retry hints, exponential backoff and positive
  jitter. Quota pauses preserve operation IDs/payloads and do not consume the ordinary
  failure retry budget. Pause further push batches; retain queued images for retry.
- [x] Add operator kill switches for images, invitations and administration snapshots;
  prohibit switches that disable core sales/sync scopes. Local writes remain independent.
- [x] Configure the enabled access/usage log alert on the existing approved email
  channel, with at most one notification/hour. Policy ID: `13320334463261700673`.
  Actual inbox delivery and broader anomaly coverage remain unverified.
- [x] Run 94 backend tests and six real local PostgreSQL abuse-test groups, including
  100 concurrent requests, exact quota admission, byte budgets and foreign-organization
  isolation. Synthetic SQL fixtures were removed. This is not pilot-scale load acceptance.
- [x] Verify live SQL `max_connections = 25` and reduce each callable pool from 5 to 1.
  Twelve single-instance callables now plan for 12 steady-state application connections.
  The former assumption of 100 total connections was incorrect. Revision overlap and
  service bursts still require a database-side runtime connection budget or pooler.
  The available IAM database account cannot alter roles; the runtime login currently
  has no role connection limit. Do not increase SQL tier or connection flags by assumption.
- [x] Complete release deployment and live synthetic quota/direct-upload checks.
  Unassigned manager/command/image actions returned permission denied; direct Storage
  upload returned 403; the access-profile quota returned 429 with a bounded retry hint.
  The temporary Auth user, App Check debug token and Storage probe were removed/verified
  absent. No business records were written. Debug-token smoke tests do not qualify
  genuine Android/web attestation. The denial event was visible in the live alert's
  log filter; email receipt remains unverified.

Release evidence (Phase 4):

- `1.0.0+3` Android and web release builds succeeded; Android signature verifies and
  matches `1.0.0+2`. AAB SHA-256:
  `229979FA38CACBC441F43283BD66BE5D63AEC08B682FC33569913F4AEC546855`.
- Web `main.dart.js` SHA-256:
  `281E44DB31100B9DDC8E9583F2D0F1A294B4381F9B543169C23DA95ACA283897`.
- All 12 Functions deployed and verified ACTIVE: max instances 1, min instances 0,
  256 MiB, 60 seconds; concurrency 10 except image finalization at 1.
  Representative revisions: `getmyaccessprofile-00003-qud`,
  `applyremotecommand-00004-hut`, `finalizeproductimage-00003-pit`.
- Flutter analysis passed; 344 Flutter tests passed (1 opt-in performance test skipped);
  formatting checked 651 files with no changes. Live Hosting reports `1.0.0+3` and
  its JavaScript SHA-256 matches the local release. Storage rules deployed successfully.
  The local synthetic PostgreSQL test server was stopped after its fixtures were removed.
- Upgrade Android and refresh web to `1.0.0+3` before testing images: older clients'
  direct Storage uploads are deliberately rejected by the new rules. Retain their
  local queued work; do not clear application data as an upgrade workaround.

**Phase 4 remains open.** Required follow-up: database-admin connection-budget
enforcement, representative pilot load/recovery tests, cumulative storage/download
cost controls, audited expiring quota increases, and remaining alert/cost coverage.
Budgets are alerts, not a guaranteed PHP 1,000 spending ceiling. Production remains
NO-GO for real/customer data; the other phases' technical launch gates still apply.

The table records implemented defaults, not proven pilot throughput. Tune through
server environment configuration and representative load tests; an audited, expiring
temporary increase workflow is still outstanding. UID and organization are the
authoritative keys; client-side scope serialization is not a server device lease.

| Operation class | Starting per-principal control | Additional control |
| --- | --- | --- |
| Access-profile reads | 30/minute/user | Reject unauthenticated/unattested calls |
| New device registration | 10/day/user | 100/day/organization; heartbeat separately 10/minute/user and 100/minute/organization |
| Remote command push | 120/minute/user | 2,000/minute/organization; backlog drains with backoff, never silent discard |
| Incremental change pull | 120/minute/user | 2,000/minute/organization; maximum 500 rows/page |
| POS bootstrap | 60 pages/minute/user | 600/minute/organization; maximum 500 rows/page; server device-session leases pending |
| Administration snapshot | 12/minute/user | 60/minute/organization; 5,000 rows/collection and 2 MiB response defaults |
| Stock-location snapshot | 30/minute/user | 300/minute/organization; same snapshot capacity bounds |
| Staff invitation generation | 10/hour/admin | 50/day/organization; App Check replay protection and audit |
| Invitation acceptance | 10/hour/account | Existing invitation authorization; risk-scored IP and mismatch alert pending |
| Manager claim grant | 20/minute/manager | 100/minute/organization; existing conflict/action/expiry bindings |
| Product image upload/finalize | 20/hour/user | 200/day/organization, 100 MiB/day attempted uploads; staging TTL |
| Branch administrative mutation | 30/minute/user | 300/minute/organization; other commands use remote-command limits |

- [x] Implement a centralized atomic rate-limit service before expensive database
  work. Use a reviewed PostgreSQL bucket table/stored function or managed Redis;
  do not rely on per-instance memory as the authoritative limiter.
- [x] Return `resource-exhausted`/HTTP 429 with a bounded `retryAfter` value. The
  client must use exponential backoff with jitter and must not convert throttling
  into a permanent sync failure.
- [ ] Exempt no human role from hard safety bounds. Provide a separately audited
  temporary increase workflow for imports, recovery, or a large legitimate backlog.
- [ ] Add per-organization quotas/entitlements for resource-heavy optional features,
  exports, date ranges, CSV rows, images, storage bytes, and background jobs.
  Enforcement must be server-side and configuration-driven.
- [ ] Add abuse alerts for rejected App Check tokens, repeated auth failures,
  device-registration churn, invitation bursts, upload bursts, unusual cross-branch
  access, and sustained 429 responses.
- [x] Set Functions `timeoutSeconds`, memory, `concurrency`, `minInstances`, and
  `maxInstances` in source-controlled runtime options. Use `minInstances: 0` unless
  measured cashier latency justifies the recurring cost.
- [ ] Protect PostgreSQL with this capacity invariant: the sum of possible function
  instances multiplied by each instance's pool maximum must stay below the approved
  database connection budget, with at least 30% reserved for migrations, monitoring,
  recovery, and operational spikes. Verified database maximum is 25, not 100.
  Pool maximum 1 gives 12 steady-state app connections, but revision overlap/bursts
  can exceed this. Set and verify a runtime-login connection cap (proposed 14), or
  an equivalent shared pool, using a database administrator before closing this gate.
- [ ] Load-test concurrency before raising caps. When a cap is reached, degraded
  sync is acceptable; data corruption, uncontrolled scale-out, or database
  exhaustion is not.
- [x] Configure ordinary billing budgets and forecast alerts at approved thresholds
  such as 50%, 75%, 90%, and 100%.
- [ ] Evaluate Google Cloud spend-cap budgets for eligible Cloud Run/Functions
  services. Because an enforced cap can pause sync and does not stop ongoing fixed
  storage/compute costs, enable it only with business-continuity approval, an offline
  operating procedure, and an emergency restoration owner.
- [x] Add Artifact Registry cleanup, Storage staging-object lifecycle, log retention,
  backup retention, and orphaned-resource cleanup policies.
  Function images older than seven days are removed, `users/` staging uploads are
  deleted after two days, bucket soft delete retains seven days, and SQL backup/log
  retention is configured for the pilot.
- [ ] Create a cost dashboard by project/service/environment and a daily anomaly
  alert. Review cost per branch, terminal, sale, sync command, image, and GiB.
- [x] Add server-controlled kill switches for non-essential expensive features.
  Core local sale/outbox persistence must not depend on a cloud flag being reachable.

Exit gate:

- [ ] Load/abuse tests prove that limits protect spend and database capacity, normal
  branch traffic is not throttled, and offline queues recover after throttling.

## Phase 5 — Offline synchronization and data-integrity qualification

Objective: prove that network loss, crashes, retries, and concurrent terminals never
lose, duplicate, or silently overwrite business data.

- [ ] Preserve these invariants in code and tests:
  - business write + audit + outbox enqueue are one SQLite transaction;
  - every mutation has a stable operation ID and server-side idempotent result;
  - dependencies are processed before dependent commands;
  - a cursor advances only after the full authorized page applies atomically;
  - tombstones converge deletions/archives without resurrecting records;
  - conflicts and permanent failures remain visible and actionable;
  - organization/branch/user/device ownership is checked on push and pull;
  - inventory, payments, shifts, receipts, corrections, and transfers remain
    immutable or use compensating records as designed.
- [ ] Add real end-to-end tests using isolated PostgreSQL, deployed/emulated
  Functions/Auth/Storage, and two independent local databases.
- [ ] Test offline durations of 1 minute, 1 hour, 24 hours, 72 hours, and the approved
  maximum; reconnect with small and large outboxes.
- [ ] Inject failures before/after local commit, request send, server commit, response,
  cursor save, change application, image copy, receipt print, and app/process kill.
- [ ] Test duplicate delivery, response loss after server commit, out-of-order
  changes, dependency chains, clock skew, stale versions, malformed envelopes,
  tombstones, expired auth, access changes, and database-full conditions.
- [ ] Test two terminals concurrently selling the same low-stock product, claiming
  a register, editing master data, archiving a branch/location, closing a shift,
  receiving a transfer, and resolving a conflict.
- [ ] Test user disablement and branch reassignment while devices are offline. Define
  exactly which operations remain locally allowed and how rejected work is handled.
- [ ] Test bootstrap and incremental-feed visibility for every permission set,
  including no-access and foreign-organization accounts.
- [ ] Add a bounded outbox retention/compaction policy that never removes unresolved
  commands or required audit/dependency evidence.
- [ ] Add reconciliation jobs/reports for sales versus payments, sales/corrections
  versus inventory, receipt sequences, shifts versus cash movements, transfers,
  purchase receipts, and server versus device pending state.
- [ ] Provide support-safe export of redacted sync diagnostics and operation IDs;
  never require direct editing of the local database.
- [ ] Verify schema 1–19 upgrades on copies of representative old device databases,
  including interrupted upgrade, low disk, rollback to the previous binary, and
  recovery without data loss.

Exit gate:

- [ ] The complete offline/multi-device/fault matrix passes, reconciliation is zero
  or explained, and no test requires deleting the local database to recover.

## Phase 6 — Functional, usability, accessibility, and hardware testing

Objective: demonstrate that real cashiers, managers, and administrators can complete
critical work safely on supported devices.

- [ ] Populate `integration_test` with automated critical journeys:
  - sign in, access refresh, branch selection, sign out, and recovery;
  - open shift, scan/search, cart edits, discount approval, split tender, checkout,
    receipt, reprint, return/void, and shift close;
  - product/category/unit/price/image administration;
  - inventory adjustment/count/location, transfer, purchase receipt, customer,
    report, settings, audit, branch, role, and staff flows;
  - offline action, restart, reconnect, sync, conflict, and reconciliation.
- [ ] Run unit, widget, integration, backend, database migration, security rules,
  and contract tests on every pull request at the appropriate speed tier.
- [ ] Add pricing/inventory property tests and malformed-input fuzz tests around
  money, quantities, tax, discounts, refunds, CSV, and remote envelopes.
- [ ] Set coverage thresholds after measuring the baseline. Require high coverage
  for Domain use cases, authorization, pricing, inventory, sync, and migrations;
  do not use coverage as a substitute for behavior assertions.
- [ ] Test the supported matrix: representative Android 10/current low/mid devices,
  approved Chrome/Edge versions, 360×640 through desktop layouts,
  100–200% text scaling, keyboard-only, touch-only, scanner, and intermittent input.
- [ ] Run accessibility checks for semantics, focus order, visible focus, contrast,
  target size, error association, screen-reader labels, reduced motion, and no
  color-only status meaning.
- [ ] Conduct task-based usability sessions with cashiers, managers, and admins.
  Measure time, errors, recovery, training questions, and accidental destructive
  actions for the top daily workflows.
- [ ] Confirm every long-running operation has non-blocking progress, clear offline
  state, safe retry, useful error text, and no duplicate submit on repeated taps.
- [ ] Test empty/loading/error/offline/conflict/pending states and very long product,
  branch, user, address, and receipt content.
- [ ] Test with the exact pilot barcode scanners, 58/80 mm ESC/POS printers, cash
  drawers, LAN topology, paper-out/offline printer, duplicate scan, and power loss.
  A print failure must never roll back a committed sale.
- [ ] Complete UAT scripts and training for sale, correction, cash handling,
  offline mode, conflict escalation, hardware failure, lost device, and outage.

Defect gate:

- [ ] No open Severity 0/1 defects. Severity 2 defects require release-manager and
  operations approval; Severity 3 defects require an owner and target version.
- [ ] Every fixed financial, sync, security, migration, or access defect has a
  permanent regression test.

Exit gate:

- [ ] QA and branch operations sign the device/hardware matrix and critical-journey
  acceptance record.

## Phase 7 — Performance, capacity, and endurance

Objective: prove responsiveness and bounded resource use at expected and abusive
loads before production traffic.

- [ ] Run the existing 10,000-product benchmark with
  `JCE_RUN_PHASE_7_PERFORMANCE=true` on representative pilot Android hardware and
  the approved web administration workstation/browser matrix.
  The Windows development-workstation baseline passed on 2026-09-18; it does not
  substitute for the required Android/web device matrix.
- [ ] Benchmark 10k/50k products, large customer/history sets, large audit logs,
  1k/10k pending outbox rows, imports, reports, bootstrap, search, checkout,
  migrations, startup, and sign-out cleanup.
- [ ] Measure p50/p95/p99 local action latency, frame jank, memory, CPU, database
  size, battery, network bytes, sync throughput, and time to drain a 72-hour backlog.
- [ ] Load-test every callable at normal peak, 2× expected peak, recovery backlog,
  and configured abuse limits against production-like staging capacity.
- [ ] Measure database CPU, memory, I/O, locks, slow queries, connection usage,
  statement timeouts, index effectiveness, and change-feed growth.
- [ ] Run an 8-hour cashier soak and a 72-hour sync/endurance test with network
  transitions, suspend/resume, background/foreground, printing, and app restarts.
- [ ] Verify pagination and lazy loading. No administration screen may load an
  unbounded organization-wide dataset.
- [ ] Tune function concurrency, maximum instances, pool size, indexes, batch sizes,
  and cache policy only from captured evidence. Record the capacity formula and
  safe maximum terminals/branches.

Exit gate:

- [ ] Approved SLOs pass on pilot hardware and production-like infrastructure with
  at least 30% database/connection headroom at 2× forecast peak.

## Phase 8 — Observability, backup, recovery, and support readiness

Objective: detect and recover from failures before they become financial or data
loss incidents.

- [ ] Select a production crash/error tool for Android and web. Configure
  release/environment tags, source maps/symbols,
  privacy filters, sampling, and retention.
- [ ] Keep backend logs structured and redacted. Include request/operation ID,
  environment, function, organization/branch pseudonymous identifiers, device,
  command type, duration, outcome, and retry class; exclude tokens, passwords,
  approval secrets, full customer data, and payment-sensitive data.
- [ ] Add metrics and dashboards for:
  - oldest/pending/retrying/permanent/conflicted outbox work;
  - push/pull/bootstrap latency, throughput, retries, cursor lag, and reconciliation;
  - callable requests, 4xx/5xx/429, cold starts, instance count, and App Check;
  - Auth failures, access denials, invites, device registrations, and manager grants;
  - PostgreSQL connections, CPU, storage, locks, slow queries, backup/PITR health;
  - Storage bytes/objects/denials and staging-object age;
  - client crash-free sessions, startup, local DB errors, UI performance, and prints;
  - spend, forecast, quota, and cost per branch/device/transaction.
- [ ] Initial alert candidates: any cross-tenant/security signal; any reconciliation
  mismatch; any permanent sale/payment failure; online outbox age >10 minutes;
  5xx >1% for 5 minutes; p95 callable latency >2 seconds for 15 minutes; sudden
  429/App Check spike; database connections/CPU >70% for 15 minutes; backup failure;
  storage >70%; budget forecast >75%.
- [ ] Route alerts to the existing production alert recipient and named primary
  release/operations contacts with acknowledgement deadlines. A separately named
  backup responder is deferred until after the pilot.
- Deferred until after the pilot: expanded narrative incident runbooks. The
  executable stop/rollback conditions in Phase 12 remain mandatory.
- [ ] Rehearse backup restore into an isolated project/database, verify checksums and
  application reconciliation, then record measured RPO/RTO.
- [ ] Prove device recovery with unsynced transactions. Never wipe or reinstall
  before preserving the local database and diagnostic evidence.
- Deferred until after the pilot: support-bundle paperwork, communication templates,
  filing, and continuity forms.

Exit gate:

- [ ] A game-day proves alerting, incident roles, database restore, device recovery,
  and business continuity within approved targets.

## Phase 9 — CI/CD, signing, and supply-chain controls

Objective: make every release reproducible, reviewed, signed, and promotable without
manual secret handling.

- [ ] Keep existing format/analyze/Flutter/backend checks and split fast unit checks
  from slower integration/performance/release jobs.
- [ ] Add CI jobs for database migration rehearsal, Auth/Functions/Storage emulator
  tests, real isolated integration environment, web release build, and Android AAB
  release build.
- [ ] Add a production-configuration test that rejects missing/wrong `JCE_ENV`, demo
  auth, diagnostics leakage, non-production project IDs, or staging Hosting targets.
- [ ] Configure a real Android release keystore or Play App Signing. Remove debug
  signing from the release build and keep key material only in protected CI secrets.
- Deferred: Windows installer, signing, update, and rollback work. Production
  startup remains fail-closed on Windows.
- [ ] Configure web production domain, TLS, HSTS, CSP, frame protection,
  `nosniff`, referrer/permissions policies, cache rules, source-map policy, and a
  tested Firebase Hosting rollback. Account for Flutter's required scripts when
  designing CSP; do not disable CSP globally.
- [ ] Use monotonically increasing version/build numbers. `1.0.0+1` must not be
  reused for production or later staging artifacts.
- [ ] Produce SHA-256 digests, signed checksums/provenance, SBOMs, migration
  compatibility evidence, and symbol/source-map archives for every artifact.
- [ ] Add automated secret scanning, CodeQL/static security analysis, dependency
  review, Dependabot/Renovate, `npm audit`, Flutter package review, license checks,
  and artifact malware scanning.
- [ ] Resolve the current `qs`/Express moderate denial-of-service findings with a
  tested dependency update. Release with no critical/high findings.
- [ ] Review the pinned Drift/sqlite3/Data Connect compatibility constraint as one
  tested upgrade unit. Do not perform broad dependency upgrades during release
  freeze without full migration/sync regression.
- [ ] Protect the production GitHub environment with required reviewers, branch
  protection, immutable logs, OIDC deployment, and least-privilege deploy roles.
- [ ] Build production artifacts from the same tagged commit, but never promote a
  staging binary configured for a staging backend. Build each production artifact
  once and promote that exact digest through release rings.
- [ ] Deploy Functions in reviewed groups and store runtime options in source so
  console drift cannot silently remove caps.

Exit gate:

- [ ] A release tag creates signed, scanned, versioned artifacts and a complete
  evidence bundle with no local credential or manual source modification.

## Phase 10 — Staging rehearsal and release-candidate acceptance

Objective: execute the exact production procedure against isolated staging using
production-like scale, permissions, and hardware.

- [ ] Refresh a restricted backup and restore rehearsal before applying migrations
  `0001`–`0016`; verify migration checksums, ownership, indexes, grants, locks, and
  counts after application.
- [ ] Remove temporary human migration-role membership after the migration window.
- [ ] Deploy Storage/App Check policy, SQL Connect schema/connectors, bounded
  Functions, and clients in the same order planned for production.
- [ ] Run all reusable staging preflight, database, callable, POS bootstrap, sync v2,
  signed-in, foreign-organization, and logical-backup checks.
- [ ] Complete the open staging gates already recorded:
  - two-device offline branch create/restart/sync/access-refresh/selection;
  - limited-admin, foreign-organization, last-admin, and archive/operation races;
  - invitation mismatch/expiry/reactivation/regeneration;
  - native Android/web smoke and physical scanner/printer/drawer tests;
  - pilot performance, reconciliation, and cashier/manager/admin UAT.
- [ ] Run rate-limit/load tests and confirm legitimate backlog recovery after 429,
  function max-instance saturation, and backend unavailability.
- [ ] Run the security test plan: modified client, invalid/expired token, missing or
  replayed App Check/device proof, IDOR, cross-tenant/branch, oversized input,
  injection, upload spoofing, enumeration, brute force, and log leakage.
- [ ] Exercise feature kill switches, previous client compatibility, client upgrade,
  server rollback, web rollback, and a deliberately failed migration rehearsal.
- [ ] Record final production capacity settings, cost forecast, support staffing,
  training completion, known defects, and risk exceptions.

Exit gate:

- [ ] The existing named primary release/security/backend owner and independent QA
  tester sign the technical release result with no unresolved blocker. Additional
  personnel assignments and filing are deferred.

## Phase 11 — Production deployment and controlled rollout

Objective: release gradually, with reconciliation and rollback available at every
step.

### Pre-deployment

- [ ] Announce the change window, freeze changes, confirm responders, open the
  release record, and verify no unresolved go/no-go gate changed since staging.
- [ ] Verify production project ID/number, region, service accounts, IAM grants,
  budget alerts/caps, quotas, dashboards, alerts, backup/PITR health, and current
  database connections.
- [ ] Take and verify a pre-change logical backup in addition to automated PITR.
- [ ] Record current Functions revisions, Hosting release, database migration table,
  Storage rules, feature flags, and client versions.
- [ ] Confirm pilot branch/terminal identifiers from approved configuration and
  validate out-of-band contact with the branch lead.

### Deployment order

1. [ ] Apply backward-compatible PostgreSQL migrations with the dedicated migration
   identity. Verify checksum, lock duration, row counts, grants, indexes, and smoke
   queries before continuing.
2. [ ] Deploy SQL Connect schema/connectors and restrictive Storage/App Check policy.
   Run unauthenticated, unauthorized, and authorized probes.
3. [ ] Deploy backward-compatible bounded Functions with old clients still supported.
   Verify revision, service account, region, runtime options, logs, App Check, rate
   limits, database connections, and signed-in smoke tests.
4. [ ] Enable non-essential features only for an internal organization or configured
   pilot branch. Keep a server-side kill switch.
5. [ ] Publish the exact signed Android release candidate to an internal ring.
   Install one terminal, preserve its old installer/data backup, then complete sale,
   print, restart, offline, reconnect, correction, shift, and reconciliation tests.
6. [ ] Expand to one pilot branch, then additional branches only after the observation
   window has zero unexplained reconciliation/sync/security errors.
7. [ ] Deploy web administration using a Hosting preview/release, validate headers,
   Auth/RBAC, data scope, and rollback, then direct approved admins to production.
8. [ ] Promote Android through managed rollout percentages. Record every artifact
   digest, device count, branch, start/end time, and
   acceptance result.

### Immediate verification after each ring

- [ ] Reconcile sales, payments, receipts, shifts, inventory, corrections, transfers,
  and purchases for the ring.
- [ ] Confirm outboxes drain, cursors advance, no permanent failures are hidden, and
  conflict volume is expected.
- [ ] Check crash-free use, p95/p99 latency, 4xx/5xx/429, App Check, database capacity,
  Storage, backup health, and spend.
- [ ] Interview the branch lead for scanner, printer, drawer, touch/keyboard, offline,
  and error-recovery usability.

Exit gate:

- [ ] All approved branches are on the recorded version, reconciliation is complete,
  alerts are normal, and operations accepts support ownership.

## Phase 12 — Rollback, hypercare, and steady-state operations

Objective: contain release problems quickly and keep the system safe after launch.

### Mandatory rollback/stop conditions

Stop expansion immediately for any of the following:

- suspected duplicate, missing, or altered financial/inventory transaction;
- authentication bypass, cross-organization/branch disclosure, secret exposure, or
  untrusted client access;
- unrecoverable local database/outbox or client migration failure;
- inability to complete the approved offline sale flow;
- widespread crash/startup/login failure;
- unexplained reconciliation mismatch;
- database saturation, sustained 5xx/429 above the approved threshold, runaway spend,
  or backup/PITR failure.

### Rollback procedure

- [ ] Stop rollout and disable only the affected non-essential feature flags.
- [ ] Preserve client databases, outboxes, logs, receipts, and server evidence. Never
  fix sync by deleting local data.
- [ ] Roll back Hosting to the previous release and Functions to the previous known
  compatible revision where safe.
- [ ] Reissue the prior signed client through the managed rollback channel if it is
  compatible with the current schema.
- [ ] Do not down-migrate a database that has accepted production writes. Prefer a
  forward fix; restore only under the approved disaster procedure with reconciliation
  and explicit business authorization.
- [ ] Keep server compatibility with the previous client for the documented rollback
  window.
- [ ] Notify branches with a precise offline/manual continuity instruction, incident
  owner, and next update time.
- [ ] Reconcile all devices and server records before resuming expansion.

### Hypercare and recurring work

- [ ] Staff hypercare through the agreed first-week window and review dashboards,
  reconciliation, oldest outbox, conflicts, crashes, latency, database headroom,
  and spend at least daily.
- [ ] Hold a 24-hour and 7-day release review. Close or assign every anomaly and
  update limits/SLOs only through reviewed configuration changes.
- [ ] Weekly: review permanent sync failures, unresolved conflicts, failed prints,
  suspicious auth/device/rate events, dependency alerts, and cost anomalies.
- [ ] Monthly: patch dependencies, restore a sample backup, test a device recovery,
  review database growth/capacity, and audit dormant users/devices.
- [ ] Quarterly: full access/IAM review, disaster-recovery game day, penetration-test
  regression, signing/secret rotation review, hardware/OS support review, and cost
  capacity forecast.
- [ ] Annually or after material architecture change: repeat threat modeling, privacy
  review, business-continuity exercise, and retention-policy validation.
- [ ] Track platform end-of-support dates and require a tested client upgrade before
  OS/browser/runtime support expires.

Exit gate:

- [ ] Hypercare ends only after seven consecutive days without an unexplained
  reconciliation, security, or data-loss incident and with all Severity 0/1 defects
  closed.

## Final production go/no-go record

Release tag/commit: ____________________  
Windows artifact/version/SHA-256: DEFERRED / NOT SHIPPED  
Android artifact/version/SHA-256: ____________________  
Web Hosting release: ____________________  
Functions revisions: ____________________  
Remote migration version/checksum: `0016` / ____________________  
Local schema version: 19  
Pilot configuration: JCE Dry Goods Trading; Branch 1 and Branch 2; one register
per branch; protected identifiers PENDING  
Backup/PITR evidence: ____________________  
Rollback artifacts verified: yes / no

| Approval | Name | Decision | Timestamp | Evidence/exception |
| --- | --- | --- | --- | --- |
| Release manager | Orlandone Estoce |  |  |  |
| Client owner | Orlandone Estoce |  |  |  |
| Backend/data owner | Orlandone Estoce |  |  |  |
| Security owner | Orlandone Estoce |  |  |  |
| QA owner | Efren Melencion |  |  |  |
| Branch operations owner | Julie Rose Estoce |  |  |  |
| Finance/billing owner | Julie Rose Estoce |  |  |  |

Production decision: **NO-GO**  
Decision notes: Infrastructure, schema/migrations, runtime access, Storage,
Functions, and web are deployed; signed Android `1.0.0+2` is built. This is not
pilot acceptance. Remaining security, multi-device sync/fault, recovery, genuine
attestation, and hardware/UAT gates must pass. Real production/customer data
remains unauthorized.

## External references

- [Firebase for Flutter platform support](https://firebase.google.com/docs/flutter/setup)
- [Firebase App Check enforcement for callable Functions](https://firebase.google.com/docs/app-check/cloud-functions)
- [Firebase App Check enforcement](https://firebase.google.com/docs/app-check/enable-enforcement)
- [Cloud Functions runtime scaling, concurrency, and maximum instances](https://firebase.google.com/docs/functions/manage-functions)
- [Google Cloud budgets and alerts](https://cloud.google.com/billing/docs/how-to/budgets)
- [Google Cloud spend-cap budgets](https://cloud.google.com/billing/docs/how-to/budgets-spend-caps)
- [Cloud Storage for Firebase billing requirements](https://firebase.google.com/docs/storage/faqs-storage-changes-announced-sept-2024)
- [Firebase SQL Connect pricing and trial limits](https://firebase.google.com/docs/sql-connect/pricing)
