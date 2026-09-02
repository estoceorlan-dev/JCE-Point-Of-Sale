# Phase 7 Remote Backend

Phase 7 defines PostgreSQL as the authoritative online store while SQLite
remains the first write target on each device. The client pushes immutable
outbox commands through `applyRemoteCommand`; authorized reads use the
generated SQL Connect SDK under `lib/core/remote/generated`.

## Environment isolation

Use one Firebase project, SQL Connect service, Cloud SQL instance, runtime
service account, and Storage bucket per environment. Reuse the stable service,
instance, and database IDs from `dataconnect/dataconnect.yaml` inside each
project; project boundaries provide the isolation.

| Alias | Project | Status |
|---|---|---|
| `development` | `jce-pos` | Live; migrations, SQL Connect, Storage, and five Functions deployed; signed-in smoke passed |
| `staging` | `jce-pos-staging-259528` | Live and isolated; migrations, SQL Connect, Storage, and five Functions deployed; signed-in smoke passed |
| `production` | `jce-pos-production-259528` | Project and dedicated runtime identity created; live resources blocked by the Cloud Billing project quota |

The aliases are checked into `.firebaserc`. Staging uses a dedicated
`jce-pos-functions` service account with the runtime roles needed for Cloud SQL,
Storage objects, and logging. Development currently uses the default App Engine
service account with the project-wide Editor role; replacing it with the same
least-privilege pattern is required during production hardening before branch
deployment. Create a matching `backend/functions/.env.<project-id>` from
`backend/functions/environment.example`; environment files remain gitignored.

Production must not reuse either live non-production database. Once billing
capacity is available, link the production project, provision its own
resources, apply the migrations, configure SQL Connect, and run the same
signed-in smoke test before any release build targets it.

## Migrations

Versioned migrations live in `backend/sql/migrations`. The migrator records a
SHA-256 checksum in `schema_migrations`, runs every new migration in its own
transaction, and rejects edits to a migration that has already been applied.
These migrations, rather than SQL Connect, own the PostgreSQL schema. Keep
migration-owned objects under a stable `NOLOGIN` owner role such as
`jce_pos_migrator`, then run SQL Connect's SQL permission setup and decline
ownership transfer so its managed reader/writer roles can access those objects.

Run against the intended environment only:

```sh
cd backend/functions
JCE_DATABASE_URL="postgresql://..." npm run db:migrate
```

The database URL is a deployment secret and must come from local or CI secret
storage. Do not commit it. Development and staging currently contain all 34
public Phase 7 tables, all three migration checksums, and all 14 permission
codes.

The checked-in `COMPATIBLE` validation mode is a deployment guard: a standard
Data Connect schema deployment must not take ownership of or generate DDL for
the migration-owned brownfield tables. After migrations and SQL permission
setup, deploy the remote schema resource through the authenticated SQL Connect
Schema API with `schemaValidation` set to `NONE`, then deploy the connector.
This disables SQL Connect DDL management for the schema; it does not disable
the GraphQL `@auth` expressions or PostgreSQL permissions. Do not change the
checked-in file to `NONE`, because the Firebase CLI accepts only `STRICT` or
`COMPATIBLE` there.

## Generate the Flutter SDK

Whenever `dataconnect/schema` or `dataconnect/pos-connector` changes, regenerate
and analyze the checked-in SDK:

```sh
firebase dataconnect:sdk:generate
flutter analyze
```

Application code consumes it only through `RemoteSyncDataSource`. Remote writes
use `RemoteCommandDataSource`, which sends the existing outbox operation ID to
the transactional callable.

## Deployment order

For each environment:

1. Apply PostgreSQL migrations.
2. Run `firebase dataconnect:sql:setup --project <project-id>` and decline
   ownership transfer for the migration-owned schema.
3. Deploy the schema contract through the authenticated SQL Connect Schema API
   with remote validation set to `NONE`, then deploy `pos-connector`.
4. Deploy Storage rules.
5. Build and deploy Firebase Functions with the environment-specific runtime
   service account.
6. Run the remote contract tests and a signed-in smoke test using a user whose
   organization/branch assignments and permission codes were provisioned.

```sh
firebase use development
firebase deploy --only storage,functions
```

Do not include `dataconnect` in that combined command for this brownfield
schema. The checked-in `COMPATIBLE` guard is expected to reject a standard
schema deployment rather than let SQL Connect attempt to manage migration-owned
tables.

Never assign permissions to named roles in migrations. `0003_permission_codes`
only seeds stable permission codes; organization administrators own role
composition.

## Security and transaction contract

- Firebase Authentication supplies the UID; clients never choose an actor UID.
- Every command verifies active organization and branch membership plus the
  required permission code.
- Command, inventory/sale side effects, audit record, change-feed entry, and
  processed-operation record commit together.
- The organization and operation ID are transaction-locked. A retry returns
  the stored result and does not reapply inventory.
- SQL Connect reads independently verify `auth.uid`, organization membership,
  branch assignment, and active role state.
- Product images upload to a user-owned staging path. The authenticated
  finalizer verifies product scope, copies to the organization path, records
  the URL transactionally, and deletes staging data after success.

Phase 8 applies pulled change-feed records into SQLite and advances the local
cursor only after the local transaction succeeds.
