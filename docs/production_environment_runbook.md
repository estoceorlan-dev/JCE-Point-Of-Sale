# Production environment provisioning runbook

Status: infrastructure-only SQL Connect trial active; production NO-GO. This
runbook does not itself authorize migration, data loading, or deployment.

## Required approved inputs

- `JCE_PRODUCTION_PROJECT`: isolated production project ID
- `JCE_APPROVED_PRODUCTION_PROJECT_ID`: independently approved value used by CI
- `JCE_FUNCTIONS_REGION`: approved production region
- `JCE_PRODUCTION_INSTANCE`: Cloud SQL instance name
- `JCE_DB_INSTANCE_CONNECTION_NAME`: `<project>:<region>:<instance>`
- `JCE_DB_NAME`: production database name
- `JCE_DB_USER`: Functions IAM database user
- `JCE_FUNCTIONS_SERVICE_ACCOUNT`: least-privilege Functions identity
- `JCE_SQL_CONNECT_SERVICE`: production SQL Connect service
- `JCE_PRODUCTION_STORAGE_BUCKET`: private production bucket
- `JCE_PRODUCTION_HOSTING_SITE`: production Hosting site
- `JCE_PRODUCTION_OWNER_LABEL`: approved lowercase Google Cloud owner label
- `JCE_PRODUCTION_COST_CENTER_LABEL`: approved lowercase cost-center label
- `JCE_SQL_AVAILABILITY_TYPE`: approved `ZONAL` or `REGIONAL` database placement
- protected deploy, migration, backup, security, and billing owners
- approved budget, spend-cap behavior, database tier, RPO/RTO, and maintenance window

No password, token, database URL, service-account JSON, private/signing key, or
customer data belongs in this runbook or a dart-define file.

## Approved pilot inputs

| Input | Approved value/status |
| --- | --- |
| Owners | Orlandone Estoce: release, client, backend/data, security; Efren Melencion: QA; Julie Rose Estoce: operations and billing |
| Privacy/backups | Privacy/legal approval PENDING; backup names intentionally blank and required before final production approval |
| Supported clients | Android 10+; latest two stable Chrome and Edge major versions; Windows production deferred |
| Pilot scope | JCE Dry Goods Trading; Branch 1 and Branch 2; one register per branch; protected IDs PENDING |
| Database availability | `ZONAL` pilot; the observed default trial is `db-f1-micro` with 10 GB SSD, automated backups/PITR disabled, and deletion protection disabled |
| Monthly cost envelope | Billing currency USD; USD 15 project budget (approximately PHP 942 at configuration time); post-trial forecast PENDING |
| Budget notifications | Email channel configured; current-spend 25/50/75/90/100%, forecast 75%; default billing-IAM recipients retained |
| Project labels | `owner=jce-pos-project`; `cost_center=jce-pos-pilot` |
| CI repository | GitHub `estoceorlan-dev/JCE-Point-Of-Sale`; tag-only OIDC/WIF active; deployer has no project roles; protected `main`, signature verification, environment reviewers, and deployment workflow PENDING |
| Retention/privacy | Approval PENDING |

## Provisioning order

1. Approve and attach only the intended Cloud Billing account. Create the
   approved budget/forecast alerts before scalable workloads, then verify quota.
2. Verify the production project is not a development/staging project and apply
   environment, owner, system, data-class, and cost-center labels.
3. Create separate runtime, deploy, migration, backup, and monitoring identities.
   Grant only their documented roles; use OIDC/workload identity for CI.
4. Provision Cloud SQL PostgreSQL with IAM authentication, automated backups,
   PITR, deletion protection, maintenance window, storage auto-growth/alerts, and
   an approved network path. Evaluate private IP/VPC rather than inheriting the
   current public-IP connector setting.
   The unchanged SQL Connect trial defaults do not satisfy this step. Enabling
   the required controls may end the trial and must follow an updated cost review.
   The authorized infrastructure-only trial began on 2026-09-16; its default
   instance and empty database exist, but this protected-production step remains
   incomplete.
5. Create the stable `NOLOGIN` migration owner and least-privilege runtime database
   grants. Do not grant the runtime identity schema ownership.
6. Apply migrations `0001`–`0015` using the dedicated migration identity after a
   fresh backup/restore rehearsal. Verify checksums, ownership, indexes, constraints,
   locks, grants, duplicates, and table counts.
7. Provision SQL Connect against the production database. Keep the migration-owned
   brownfield schema behavior described in `phase_7_remote_backend.md`.
8. Provision private Storage and the production Hosting site. Configure the
   `production-web` target without altering `staging-web`.
9. Register production Android and web clients. Copy only public Firebase client
   identifiers into gitignored per-platform release-config files.
10. Provision the least-privilege Functions runtime identity and environment
    parameter file from `backend/functions/environment.example`.
11. Deploy only after Phase 3–4 App Check, rate, scaling, and cost controls are
    implemented and staging-qualified.
12. Run unauthenticated, limited-role, cross-tenant, signed-in, bootstrap, sync,
    backup, restore, and reconciliation checks before any branch is enrolled.

## Client configuration validation

```powershell
dart run tool/validate_release_config.dart `
  --config=config/production_android.local.json `
  --platform=android `
  --expected-project=$env:JCE_APPROVED_PRODUCTION_PROJECT_ID
```

Only after validation:

```powershell
flutter build appbundle `
  --release `
  --dart-define=JCE_APPROVED_PRODUCTION_PROJECT_ID=$env:JCE_APPROVED_PRODUCTION_PROJECT_ID `
  --dart-define-from-file=config/production_android.local.json
```

Repeat with `production_web.local.json` and `--platform=web`. Windows intentionally
fails until ADR-0001 is superseded.

## Required preflight evidence

- project number/ID, region, labels, billing owner, budgets, and quotas;
- identities, effective IAM, conditional grants, and no broad Editor/Owner runtime;
- Cloud SQL state, connection name, network path, IAM user, backup/PITR/deletion
  protection, last successful backup, capacity, and connection reserve;
- migration checksums through `0015`, schema ownership, runtime grants, and indexes;
- SQL Connect datasource points only to production;
- Auth, Storage, Functions, Hosting, and client app IDs all belong to production;
- release configuration validator passes without printing values;
- restore rehearsal meets approved RPO/RTO;
- no temporary human migration membership remains after verification.

After the resources exist, run the read-only preflight. It prints identifiers
and control state but never credentials:

```powershell
Set-Location backend/functions
npm run production:preflight
```

The command requires every approved `JCE_*` identifier listed above and
Application Default Credentials with read-only visibility. It fails for a
development/staging project, inconsistent connection name, missing expected
database/database user, cross-project or disabled runtime identity, disabled
backup/PITR/deletion protection, missing successful backup, project-wide
Owner/Editor/Storage Admin/Object Admin runtime roles, missing production label,
disabled/unreadable billing, missing Android/web client registration, or
cross-project Storage bucket. It also validates the configured owner/cost-center
labels and Cloud SQL availability type. API quota for every check is explicitly
assigned to the approved production project so development cannot hide missing
production API enablement.

Latest evidence (2026-09-16): Cloud Billing is linked and a production-project
budget and email channel are configured. Production Android/web Firebase apps were
registered and their gitignored configurations validate and compile. Environment,
system, data-class, owner, and cost-center labels were applied. The project-wide
Storage Object Admin grant was removed from the runtime identity, and separate
keyless deployer, migrator, and backup identities were created without roles. The
empty SQL Connect service, default trial Cloud SQL instance, and logical database
now exist. No schema, connector, migration, runtime database user, or real data
was deployed. The preflight still fails because Storage is absent and the trial
has no backups, PITR, deletion protection, successful backup, or runtime database
user. See the [trial record](sql_connect_trial_record.md).

GitHub Workload Identity Federation uses pool `github-actions` and provider
`jce-pos-production`. The provider accepts only tag refs from the exact approved
repository. It grants only `roles/iam.workloadIdentityUser` on the role-free
production deployer service account. Do not add deploy roles until the GitHub
`production` environment, protected `main`, signed-tag verification, required
reviewers, and resource-specific least-privilege role list are approved.

## Stop conditions

Stop immediately if an identifier resolves to development/staging, the project is
not billing-approved, a secret would be printed or committed, runtime IAM is broad,
backup/PITR is unhealthy, a migration checksum differs, ownership is unexpected,
or ADR-0001 is bypassed.
