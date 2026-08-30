# User access provisioning

JCE POS does not expose account bootstrap through the Flutter application or a
callable Cloud Function. Create the Firebase Authentication user through an
approved operator workflow, configure the organization, branch, role, and role
permissions separately, then map that Firebase UID to the existing role with
the operator-only script in this directory.

The script requires direct PostgreSQL credentials and must only be run from a
trusted administrative environment. It validates that the organization, role,
and optional branch are active and belong to the same organization. It never
creates roles or grants permissions.

Required environment variables:

- `JCE_DATABASE_URL`
- `JCE_ACCESS_FIREBASE_UID`
- `JCE_ACCESS_EMAIL`
- `JCE_ACCESS_DISPLAY_NAME`
- `JCE_ACCESS_ORGANIZATION_ID`
- `JCE_ACCESS_ROLE_ID`

Optional environment variables:

- `JCE_ACCESS_BRANCH_ID` - omit for an organization-wide assignment
- `JCE_ACCESS_USER_ID` - omit to reuse a matching user or generate an ID

From `backend/functions`, run:

```text
npm run access:provision
```

Do not store database credentials, Firebase credentials, passwords, or personal
account identifiers in the repository. After removing an older bootstrap path,
reset any exposed password and revoke that Firebase user's refresh tokens.

## Database schema migrations

Run migrations before deploying Functions that depend on a new schema. For a
direct PostgreSQL connection, set `JCE_DATABASE_URL` and run:

```text
npm run db:migrate
```

For Cloud SQL automatic IAM database authentication, set:

- `JCE_DB_INSTANCE_CONNECTION_NAME`
- `JCE_DB_NAME`
- `JCE_DB_USER`

Set `JCE_DB_MIGRATION_ROLE` when the IAM database user is a temporary member
of the schema-owning `NOLOGIN` role. The migration runner validates this role
name and issues `SET ROLE` before applying migrations.

Then run:

```text
npm run db:migrate:iam
```

The IAM command uses Application Default Credentials by default. An operator
may instead supply a short-lived token through `JCE_GOOGLE_ACCESS_TOKEN` and,
optionally, its ISO-8601 expiry through
`JCE_GOOGLE_ACCESS_TOKEN_EXPIRES_AT`. Never store or log these values.
