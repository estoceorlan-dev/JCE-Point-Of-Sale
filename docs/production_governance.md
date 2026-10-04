# Production governance and release policy

Status: primary owners nominated; backups and policy approval pending  
Effective for: every JCE POS production release  
Related plan: [Production deployment plan](production_deployment_plan.md)
Related security baseline: [Production client threat model](production_client_threat_model.md)

## Release boundary

The first production candidate is limited to:

- Android for POS and approved operational workflows;
- web for administration and operational fallback, with the POS route disabled;
- no Windows production release until
  [ADR-0001](adr/0001_windows_production_transport.md) is superseded.

Development and staging remain available on Windows for implementation and pilot
validation. Linux, iOS, and macOS are outside the current production boundary.
The approved initial support baseline is Android 10 or newer and the latest two
stable major versions of Chrome and Edge. Pilot hardware/browser validation must
still pass before release; supported versions must not be inferred at runtime.

## Required owners

No production change may begin while a required primary or backup is blank.

| Role | Primary | Backup | Approval state |
| --- | --- | --- | --- |
| Release manager | Orlandone Estoce |  | Nominated; acceptance pending |
| Client owner | Orlandone Estoce |  | Nominated; acceptance pending |
| Backend/data owner | Orlandone Estoce |  | Nominated; acceptance pending |
| Security owner | Orlandone Estoce |  | Nominated; acceptance pending |
| QA owner | Efren Melencion |  | Nominated; acceptance pending |
| Branch operations owner | Julie Rose Estoce |  | Nominated; acceptance pending |
| Finance/billing owner | Julie Rose Estoce |  | Nominated; acceptance pending |
| Privacy/legal approver | PENDING |  | PENDING |

QA is assigned independently from the release manager. Backup names are
intentionally blank for now. They and the privacy/legal approver remain required
before the final production exit gate can pass.

## Incident severity and release defect policy

| Severity | Definition | Initial response target | Release rule |
| --- | --- | --- | --- |
| Severity 0 | Active security breach, cross-tenant disclosure, or confirmed financial/data corruption | Immediate; acknowledge within 15 minutes | Stop/rollback immediately |
| Severity 1 | Core sign-in, sale, payment, shift, sync, or recovery unavailable with no safe workaround | Acknowledge within 30 minutes | No release; stop rollout |
| Severity 2 | Material degradation with a safe documented workaround | Same business day | Requires release and operations risk approval |
| Severity 3 | Minor defect with low operational impact | Next triage cycle | Owner and target release required |

The response targets remain proposed until the named owners approve them. Every
financial, synchronization, access, migration, or security fix requires a
permanent regression test.

## Service and recovery objectives

| Objective | Proposed target | Approval |
| --- | --- | --- |
| Callable availability | 99.9% monthly, excluding declared maintenance | PENDING |
| Ordinary online sync | 99% of operations accepted within 2 minutes | PENDING |
| Oldest eligible online outbox alert | 10 minutes | PENDING |
| Offline core POS continuity | 72 hours on supported managed devices | PENDING |
| PostgreSQL recovery point | <=5 minutes through tested PITR | PENDING |
| PostgreSQL recovery time | <=4 hours | PENDING |
| Local search/checkout | Existing 10,000-product benchmark thresholds | PENDING |

Offline continuity is not an authorization bypass. The approved offline-access
age, role restrictions, and lost-device response must be finalized during the
security phase.

## Change and release policy

- Production changes originate from a protected tag and reviewed pull request.
- Production deployment requires a signed release tag whose commit is contained
  in the protected `main` branch. A push to `main` alone must not deploy.
- The release candidate freezes feature work. Only documented blockers with QA
  evidence may be merged after the freeze.
- Staging uses the same deployment order, migration set, runtime options, and
  artifact-building process as production.
- Production artifacts are rebuilt for production configuration from the same
  tagged commit; a staging-configured binary is never promoted.
- Every release record includes exact artifact hashes, database migration state,
  Functions revisions, Hosting release, approvals, backup evidence, pilot scope,
  known defects, and rollback artifacts.
- Pilot organization/branch/register/device IDs are supplied in the protected
  release record or deployment environment. They are never source constants.
- The release manager may stop a rollout. The security owner may stop a rollout
  for a suspected security issue. The backend/data owner may stop it for an
  integrity, migration, capacity, or backup concern.
- Database rollback is forward-fix-first. Never down-migrate a database that has
  accepted production writes without explicit disaster authorization and full
  reconciliation.
- Local SQLite/outbox data is evidence. Do not wipe, reinstall, or delete it as a
  routine sync recovery step.

## Maintenance and communication

The release record must specify:

- approved change window and timezone;
- branch leads and an out-of-band contact method;
- primary/backup incident responders;
- maintenance and outage wording;
- next-update cadence;
- offline/manual continuity instructions;
- rollback decision time and authority.

## Approval

Policy owner: PENDING  
Approved version/date: PENDING  
Next review: PENDING
