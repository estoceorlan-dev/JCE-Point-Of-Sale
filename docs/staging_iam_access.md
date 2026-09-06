# Staging IAM migration access

These are operator instructions, not an automatic permission grant. Do not use
the production project or the POS application password for these steps.

## Target and current state

Update: the operator completed the temporary role grant. IAM `SET ROLE`, schema
USAGE/CREATE and live migrations through `0012` subsequently passed.
The instructions below remain the reproducible setup/cleanup procedure; do not
repeat grants unnecessarily. The user approved Functions Auth permissions and
application-role provisioning; both are configured, and staging schema/connector
and all eight Functions are deployed. The custom runtime Auth role contains only
users.create/get/sendEmail/update. Approved administration grants were audited.
Temporary migration membership remains present: perform step 5 after database
work is finished. See the staging checkpoint.

- Project: `jce-pos-staging-259528`
- Cloud SQL instance: `jce-pos-instance`, region `asia-southeast1`
- Database: `jce-pos-database`
- Human IAM database user: `estoce.orlan@gmail.com`
- Existing PostgreSQL schema-object owner: `jce_pos_migrator`

The initial preflight on 2026-09-06 successfully authenticated this IAM user. Migrations
`0001`-`0004` matched, `0005`-`0011` were pending, and migration-role membership
was false. That initial PostgreSQL authorization blocker is now resolved.

## 1. Verify Google Cloud access

Select the staging project in Google Cloud Console. In IAM & Admin > IAM, verify
effective access for the human account includes Cloud SQL Client
(`roles/cloudsql.client`) and Cloud SQL Instance User
(`roles/cloudsql.instanceUser`). Existing inherited/equivalent permissions count;
do not add duplicate or broader roles when connectivity already works.

Under SQL > jce-pos-instance > Users, verify the email exists as an IAM user.
It already existed during preflight; do not create a built-in password user with
the same name. Do not change instance flags or reset passwords for this task.

Console SQL Studio additionally requires its own IAM access, such as Cloud SQL
Studio User (`roles/cloudsql.studioUser`), plus database-level privileges. An
authorized administrator can instead use their existing PostgreSQL client.

References: [IAM database users](https://docs.cloud.google.com/sql/docs/postgres/add-manage-iam-users),
[SQL Studio](https://docs.cloud.google.com/sql/docs/postgres/manage-data-using-studio).

## 2. Have a PostgreSQL role administrator grant temporary membership

Open SQL Studio for the staging instance and select `jce-pos-database`. Sign in
with an existing database account authorized to grant membership in
`jce_pos_migrator`. This could be the provisioning administrator; a Google Cloud
Owner or POS administrator is not automatically a PostgreSQL role administrator.
Use `postgres` only if it is an authorized account with the required role-grant
authority. Enter database passwords only in the secure login dialog.

Confirm the connection, then have that administrator execute:

```sql
SELECT current_database(), session_user, current_user;
GRANT jce_pos_migrator TO "estoce.orlan@gmail.com";
```

This grants schema-owner capabilities and should be temporary. Do not grant
`WITH ADMIN OPTION`, change table ownership, or give the Functions runtime
identity the migration role. If permission is denied, stop and contact the
administrator who controls that role; do not try escalating to other identities.

## 3. Verify using the human IAM login

Reconnect with IAM authentication as `estoce.orlan@gmail.com` to the staging
database. Run this entire block together; SQL Studio does not preserve sessions
between separate script executions:

```sql
BEGIN;
SET LOCAL ROLE jce_pos_migrator;
SELECT current_database(), session_user, current_user,
       has_schema_privilege(current_user, 'public', 'USAGE') AS schema_usage,
       has_schema_privilege(current_user, 'public', 'CREATE') AS schema_create;
ROLLBACK;
```

Expected: database `jce-pos-database`, session user the human email, current user
`jce_pos_migrator`, and both schema privileges true. This block changes no
database records or schema. If CREATE/USAGE is false, ask the schema administrator
to review the migration owner's schema privileges before proceeding.

PostgreSQL documents the distinction between role membership and `SET ROLE` in
its [role membership guide](https://www.postgresql.org/docs/current/role-membership.html).

## 4. Hand back for migration preflight

Share the verification result or a redacted error, never passwords or tokens.
After access is verified, the operator configures the migration process with
the existing Google application credentials and these non-secret identifiers:

```powershell
$env:JCE_DB_INSTANCE_CONNECTION_NAME='jce-pos-staging-259528:asia-southeast1:jce-pos-instance'
$env:JCE_DB_NAME='jce-pos-database'
$env:JCE_DB_USER='estoce.orlan@gmail.com'
$env:JCE_DB_MIGRATION_ROLE='jce_pos_migrator'
```

Do not run `npm run db:migrate:iam` until the fresh backup, checksum, normalized
branch-code and explicit application-permission provisioning reviews pass.
The runner's `SET ROLE` makes new objects belong to the stable owner role.

Corrected migration `0011` seeds permission definitions only. Before enabling
administration, approve specific organization/role IDs for `branches.manage`
and `roles.manage`, verify intended organization-wide assignments, and record
the provisioning change. Do not infer grants from role names. The existing
`access:provision` script assigns users to roles; it does not grant role permissions.
Do not rewrite an already-applied migration checksum in any other environment.

## 5. Remove temporary access after deployment verification

Once migration processes have disconnected and verification is complete, the
same authorized role administrator removes the membership added for this task:

```sql
REVOKE jce_pos_migrator FROM "estoce.orlan@gmail.com";
```

Keep the existing IAM login/runtime permissions intact. Recheck that migration
role access is removed and ordinary staging application operations still work.
