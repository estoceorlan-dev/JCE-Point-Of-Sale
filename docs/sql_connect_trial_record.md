# SQL Connect infrastructure-only trial record

Status: ACTIVE FOR INFRASTRUCTURE TESTING; PRODUCTION NO-GO  
Authorized by: Orlandone Estoce  
Authorization date: 2026-09-16  
Project: `jce-pos-production-259528`  
Region: `asia-southeast1`

## Authorization boundary

The owner authorized the default SQL Connect trial to begin immediately and
accepted the 90-day trial clock. This authorization is limited to empty
infrastructure. It does not authorize real production/customer data, PostgreSQL
migrations, a SQL Connect schema or connector deployment, Functions/Hosting/
Storage deployment, pilot enrollment, or a production release.

Production remains `NO-GO` until the deployment plan's remaining gates are
approved and evidenced.

## Provisioned resources

| Resource | Identifier | Verified state |
| --- | --- | --- |
| SQL Connect service | `jce-pos-service` | Present; not reconciling; 0 schemas and 0 connectors |
| Cloud SQL instance | `jce-pos-instance` | `RUNNABLE`; trial label `firebase-data-connect=ft` |
| PostgreSQL database | `jce-pos-database` | Present; no application migrations were run |

Cloud SQL reported `createTime=2026-09-16T11:05:15.089Z`; the create operation
was accepted at `2026-09-16T11:05:21.516Z` (2026-09-16 19:05 Asia/Manila). The
internal 90-day decision/shutdown deadline is **2026-12-15 19:05 Asia/Manila**.
Confirm the provider-displayed expiration before that date; do not rely on the
budget alert as an automatic shutdown.

## Immutable trial baseline

- PostgreSQL 18, `db-f1-micro`, Enterprise edition
- `ZONAL` placement in `asia-southeast1`
- 10 GB `PD_SSD`
- Cloud SQL IAM authentication flag enabled
- storage auto-resize disabled
- automated backups disabled
- point-in-time recovery disabled
- deletion protection disabled
- no SQL Connect schema or connector

Changing the Cloud SQL defaults can end trial treatment. Do not modify the
instance, deploy the application schema, create the runtime database user, or
load any real data under this authorization.

## Verification and NO-GO evidence

The read-only production preflight now sees the SQL instance, target database,
and SQL Connect service. It intentionally fails because:

- the production Storage bucket is absent;
- automated backups and PITR are disabled;
- deletion protection is disabled;
- no successful backup exists; and
- the production runtime database user is absent.

The SQL Connect list APIs returned zero schemas and zero connectors. The trial
quota metric returned `1`, confirming the project has consumed its SQL Connect
trial allocation. No migrations `0001` through `0015` were executed and no
application/customer data was loaded.

## Required decision before the deadline

Before 2026-12-15 19:05 Asia/Manila, approve one of these controlled paths:

1. delete/shut down the unused trial resources after evidence capture; or
2. approve forecast cost and a paid protected configuration, then enable backups,
   PITR, deletion protection, monitoring, least-privilege database access, and
   complete the remaining production gates before any real data is introduced.

