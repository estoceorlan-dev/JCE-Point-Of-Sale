# Phase 2 access backend contract

> Historical Firebase implementation/deployment record. Firebase runtime and deployment
> commands below are retired. Use [Node installation](node_installation.md) and
> the [source retirement record](firebase_source_retirement.md) for current operation.

The Flutter client uses Firebase Authentication for identity and PostgreSQL for
application access. Apply `backend/sql/phase_2_access_control.sql` to the
environment database before enabling production authentication.

## Callable: getMyAccessProfile

The callable is implemented in `backend/functions/src/index.ts`. It requires a
valid Firebase ID token and uses its UID server-side.
It must not accept a user ID from the client. Suspended, disabled, missing, and
cross-organization records must be denied.

Response shape:

```json
{
  "user": {
    "firebaseUid": "firebase-uid",
    "email": "user@example.com",
    "displayName": "User Name"
  },
  "organizations": [
    {
      "appUserId": "application-user-id",
      "status": "active",
      "organization": {
        "id": "organization-id",
        "code": "JCE",
        "name": "JCE",
        "timezone": "Asia/Manila"
      },
      "organizationRoles": [
        {
          "id": "role-id",
          "code": "owner",
          "name": "Owner",
          "permissions": ["dashboard.view", "settings.manage"]
        }
      ],
      "branches": [
        {
          "branch": {
            "id": "branch-id",
            "code": "MAIN",
            "name": "Main Branch",
            "timezone": "Asia/Manila"
          },
          "roles": []
        }
      ]
    }
  ]
}
```

Only active branches should be returned. Organization-level roles apply to
every returned branch. Branch roles apply only to their matching branch.
Unknown permission codes are ignored by older clients, allowing permissions to
be introduced without granting unintended access.

## Callable: registerDevice

The callable receives `deviceId`, `platform`, `organizationId`, and `branchId`.
It must verify that the authenticated Firebase UID maps to an active
`app_users` row and that the branch is assigned before upserting `devices`.

If registration is unavailable, the client queues a `device.register` outbox
command and continues offline.

## Callable: updateBranchName

Users with `settings.manage` may edit the active branch name/label from the
Settings page. The callable validates the Firebase UID, organization and branch
assignment, and permission before updating `branches.name`. Offline edits are
written to Drift immediately and queued as `branch.update_name`.

## Deployment

```sh
cd backend/functions
npm install
npm run build
```

For the `jce-pos` Firebase project, Functions connect to SQL Connect through
Cloud SQL IAM auth. Do not create a public database URL for the app path.
Keep these non-secret deployment values in `backend/functions/.env.jce-pos`:

```dotenv
JCE_FUNCTIONS_REGION=asia-southeast1
JCE_DB_INSTANCE_CONNECTION_NAME=jce-pos:asia-southeast1:jce-pos-instance
JCE_DB_NAME=jce-pos-database
JCE_DB_USER=jce-pos@appspot
JCE_FUNCTIONS_SERVICE_ACCOUNT=jce-pos@appspot.gserviceaccount.com
```

The PostgreSQL schema is applied to the SQL Connect Cloud SQL database
`jce-pos-database` on instance `jce-pos-instance`. The deployed runtime service
account must have:

- SQL Connect `writer` SQL role on the database.
- Google Cloud permission to connect to Cloud SQL.

Then deploy:

```sh
firebase deploy --only functions --project jce-pos
```

The Flutter client defaults to the deployed Functions region
`asia-southeast1`. Override it only when pointing at another Firebase project:

```sh
flutter run --dart-define=JCE_FIREBASE_FUNCTIONS_REGION=us-central1
```

`backend/functions/scripts/apply-schema.js` remains available for environments
that intentionally use a direct PostgreSQL connection URL, but that is not
required for the Firebase SQL Connect setup.

## Security requirements

- Resolve the Firebase UID from the verified token.
- Re-check permission codes for every protected backend operation.
- Verify organization and branch membership on every request.
- Never trust hidden navigation or client-supplied role names.
- Record login, logout, failed login, branch switch, and role change events.
