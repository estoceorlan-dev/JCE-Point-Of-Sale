# Phase 0–2 production-readiness implementation checkpoint

Updated: 2026-09-16  
Scope: repository and authorized production-foundation work  
Production cloud/resource changes: labels, IAM hardening, service accounts,
Firebase Android/web app registrations, Cloud Billing linkage, a scoped
budget/email notification channel, a keyless GitHub Workload Identity Federation
provider, and the authorized empty SQL Connect trial infrastructure. No real
production/customer data, application migration, SQL Connect schema/connector,
Functions, Hosting release, or Storage deployment occurred.

## Implemented

### Phase 0

- Production governance, severity, release, change, and rollback policy template.
- Technical data-classification register with explicit business/legal retention
  approvals left pending.
- Production risk register and per-release evidence/go/no-go template.
- Primary release, client, backend/data, security, QA, operations, and billing
  owners are nominated. Privacy approval and named backups remain pending.
- Android 10+, the latest two stable Chrome/Edge major versions, a two-branch
  one-register-per-branch pilot, zonal Cloud SQL, a PHP 1,000 monthly cost
  envelope, and the GitHub CI repository are recorded.
- Production delivery is defined as a signed release tag whose commit belongs to
  the protected `main` branch; direct `main` pushes cannot deploy production.
- Pilot identifiers are defined as protected release/deployment inputs, never
  source constants.
- Secret filename patterns, signing keys, and local release configurations are
  excluded from Git. The external `C:/JCE/credentials.md` was not read or changed.
- Current documentation records staging migrations through `0015`, 63 public
  tables, 12 Functions, and local schema 19 without rewriting older dated evidence.

### Phase 1

- [ADR-0001](adr/0001_windows_production_transport.md) records the interim safe
  decision to defer production Windows while retaining Windows staging/pilot use.
- The [production client threat model](production_client_threat_model.md) records
  assets, trust boundaries, platform authentication/device-trust paths, threats,
  existing controls, and later release gates.
- Production startup rejects Windows and all non-approved platforms.
- Production Android remains POS-capable.
- Production web is limited to administration/operational fallback: the POS
  destination is removed and direct POS navigation redirects to an allowed route.
- Android Play Integrity and web reCAPTCHA Enterprise are the selected Phase 3
  App Check providers. Enforcement is not claimed in Phase 0–2.
- No shared client secret or bypass override was added.
- Domain source imports remain independent of Flutter and Firebase; Windows
  transport contract tests remain an ADR supersession requirement because no
  alternate Windows transport ships in this release.

### Phase 2

- Profile/release builds require explicit `JCE_ENV` and reject development.
- Production rejects demo authentication and enabled diagnostics.
- Development and staging display a permanent environment banner.
- Production Firebase client identifiers load from a per-platform
  `--dart-define-from-file`; known development/staging project IDs, missing values,
  placeholders, and a mismatch with the independently supplied approved project
  ID fail closed during validation and startup.
- A release-config validator independently compares the configured project with
  the protected approved project ID and rejects Windows production.
- Gitignored Android/web local configuration workflow and public examples exist.
- Production Android and web Firebase apps are registered. Their generated public
  client settings are stored in gitignored local configuration files and both
  pass the independent approved-project validator.
- The production web release build and Android debug validation build compile
  successfully. No debug-signed Android artifact is approved for distribution.
- Firebase Hosting now has separate `staging-web` and `production-web` targets;
  the production alias mapping is present but has not been deployed.
- A read-only production preflight validates project isolation, Firebase/Cloud SQL/
  SQL Connect/Storage/Hosting existence, billing state, registered clients,
  runtime IAM, backups, PITR, deletion protection, labels, and cross-project
  identifiers. It explicitly assigns API quota to production and performs no
  mutation.
- Production provisioning and build procedures are documented in
  [the runbook](production_environment_runbook.md).
- A production GitHub OIDC provider accepts only tag-ref tokens from
  `estoceorlan-dev/JCE-Point-Of-Sale` and may impersonate the keyless deployer.
  The deployer intentionally has no production project roles yet.
- The infrastructure-only SQL Connect trial started on 2026-09-16. Its empty
  service, default zonal `db-f1-micro` PostgreSQL 18 instance, and logical
  database are present. SQL Connect reports zero schemas and zero connectors;
  migrations `0001` through `0015` were not run.

## Automated evidence

- Dart formatting check passed across `lib`, `test`, and `tool`.
- `flutter analyze`: no issues.
- Full Flutter suite: 333 passed; 1 opt-in performance benchmark skipped.
- Backend lint/security/type checks passed.
- Backend tests: 64 passed, including 5 production preflight/isolation tests.
- Firebase, Hosting, and example release configuration JSON parsed successfully.
- Production web release compilation passed.
- Production Android debug validation compilation passed after increasing the
  Gradle heap from 2 GB to 4 GB. Production signing remains a later gate.

## Read-only production preflight result

The latest 2026-09-16 preflight reached the active isolated Firebase project,
existing Hosting site, SQL instance/database, empty SQL Connect service, intended
runtime service account, and project IAM. The
project now has `environment=production`, `system=jce-pos`,
`data_class=restricted`, `owner=jce-pos-project`, and
`cost_center=jce-pos-pilot` labels. The project-wide `roles/storage.objectAdmin`
grant was removed from the runtime identity. It returned `NO-GO` because:

- the expected Storage bucket returned 404;
- automated backups, PITR, and deletion protection are disabled by the untouched
  trial defaults;
- there is no successful backup; and
- the runtime database user is intentionally absent.

Cloud Billing now passes. The production project has a scoped USD 15 budget
(approximately PHP 942 at configuration time), current-spend alerts at
25/50/75/90/100%, a 75% forecast alert, and a configured email channel. Budgets
are alerting controls and do not cap Cloud SQL or Storage spend.

Separate keyless, role-free deployer, migrator, and backup service accounts were
created. Their least-privilege roles and CI impersonation remain pending because
the target resources and CI identity do not yet exist.

The preflight output contained control state and identifiers only; it did not
print or inspect credentials.

## Intentionally pending external gates

These items cannot be truthfully completed by source changes alone:

- the privacy/legal approver, named backup owners, and final go/no-go signatures;
- business/privacy/legal retention approval and third-party processor review;
- protected pilot organization/branch/register/user/device IDs and physical
  hardware/browser acceptance;
- migration of any active values in `C:/JCE/credentials.md`, rotation, and secure
  deletion by the credential owner;
- post-trial pricing within the PHP 1,000 cost envelope, service quota
  confirmation, and approved spend-cap/shutdown behavior;
- completion of Auth verification, Storage, monitoring, backup, PITR, network,
  runtime database access, SQL Connect schema/connector deployment, and
  least-privilege IAM after explicit authorization;
- exact Cloud SQL tier, storage capacity, maintenance window, and network path;
- a decision to leave the no-cost default SQL Connect configuration for isolated
  testing or exit the trial and enable mandatory automated backups, PITR, and
  deletion protection; the infrastructure-only trial is active and its observed
  default configuration disables all three;
- GitHub protected-`main` enforcement, production environment reviewers,
  signed-tag verification, and least-privilege deployer roles;
- final client configuration review after the production Storage bucket exists;
- a successful read-only preflight and backup/restore rehearsal;
- Windows transport/device-trust implementation if Windows must be in the first
  production release.

Phase 0–2 therefore has implemented repository controls but remains `NO-GO` for
production until the pending approvals/resources have evidence. Later Phase 3–12
security, rate-limit, sync, end-to-end, signing, observability, UAT, deployment,
and hypercare gates also remain mandatory.

## Credential-handling incident

During the 2026-09-15 audit, `firebase login:list --json` unexpectedly printed the
cached Firebase CLI OAuth credentials to tool output. `firebase logout` immediately
revoked the refresh token successfully and removed the active Firebase CLI login.
No token was written to the repository or reused. Firebase CLI work now requires
a fresh interactive login.
