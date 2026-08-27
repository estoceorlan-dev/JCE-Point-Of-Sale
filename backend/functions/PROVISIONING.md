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
