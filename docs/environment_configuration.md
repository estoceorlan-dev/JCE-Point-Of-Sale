# Environment Configuration

## Environments

JCE POS has three explicit environments:

| Environment | Purpose | Demo authentication | Diagnostics |
|---|---|---:|---:|
| Development | Local development and automated tests | Allowed explicitly | On by default |
| Staging | Release candidate and integration verification | Off by default | On by default |
| Production | Branch deployment | Disabled | Off by default |

Each environment should use a separate Firebase project, SQL Connect database,
service account boundary, and deployment pipeline. Production data must never
be copied into development.

## Dart define values

| Key | Required | Description |
|---|---:|---|
| `JCE_ENV` | Yes for release builds | `development`, `staging`, or `production` |
| `JCE_API_BASE_URL` | No | Reserved absolute URL for future non-Firebase services |
| `JCE_ENABLE_DEMO_AUTH` | No | Enables the development-only demo repository |
| `JCE_DEMO_BRANCH_ID` | When demo auth is enabled | Non-production demo branch identifier |
| `JCE_ENABLE_DIAGNOSTICS` | No | Enables additional non-sensitive diagnostics |
| `JCE_FIREBASE_FUNCTIONS_REGION` | Production | Firebase Functions region; non-production defaults to `asia-southeast1` |
| `JCE_FIREBASE_API_KEY` | Production | Platform-specific public Firebase client identifier |
| `JCE_FIREBASE_APP_ID` | Production | Platform-specific production Firebase app ID |
| `JCE_FIREBASE_MESSAGING_SENDER_ID` | Production | Production Firebase sender/project number |
| `JCE_FIREBASE_PROJECT_ID` | Production | Isolated production Firebase project ID |
| `JCE_APPROVED_PRODUCTION_PROJECT_ID` | Production build | Independently approved production project ID supplied by protected CI |
| `JCE_FIREBASE_AUTH_DOMAIN` | Production web | Production Firebase Auth domain |
| `JCE_FIREBASE_STORAGE_BUCKET` | Production | Private production Storage bucket identifier |
| `JCE_ACCESS_PROFILE_FUNCTION` | No | Callable name used to load the current access profile |
| `JCE_DEVICE_REGISTRATION_FUNCTION` | No | Callable name used to register the local device |
| `JCE_UPDATE_BRANCH_NAME_FUNCTION` | No | Callable name used to update a branch label |
| `JCE_REMOTE_COMMAND_FUNCTION` | No | Transactional outbox command callable; defaults to `applyRemoteCommand` |
| `JCE_FINALIZE_PRODUCT_IMAGE_FUNCTION` | No | Authenticated product-image finalizer callable |

Values are parsed by `AppConfig` and can be replaced in tests through
`appConfigProvider.overrideWithValue(...)`.

For the `jce-pos` Firebase project, the Flutter app automatically targets
`asia-southeast1`, matching the deployed callable Functions. Set
`JCE_FIREBASE_FUNCTIONS_REGION` only when running against another Firebase
project or region.

Firebase client options are selected from `JCE_ENV`. Development uses
`jce-pos`, staging uses `jce-pos-staging-259528`, and production requires its
platform identifiers through a validated `--dart-define-from-file` configuration.
Protected CI supplies `JCE_APPROVED_PRODUCTION_PROJECT_ID` separately to the
validator and build so runtime startup also enforces the approved project.
Production rejects known development/staging project IDs and missing placeholder
values. Android uses explicit Dart Firebase options instead of native Google
Services resource auto-initialization so a staging binary cannot silently attach
to development.

Profile and release builds require an explicit `JCE_ENV` and reject
`development`. Production also rejects demo auth and enabled diagnostics.
Development/staging render a visible environment banner. Production Windows is
blocked by [ADR-0001](adr/0001_windows_production_transport.md), while production
web omits and rejects the POS route.

See [Phase 7 remote backend](phase_7_remote_backend.md) for isolated Firebase,
SQL Connect, Cloud SQL, and Storage environment provisioning and deployment.

## Firebase Functions environment values

These values are non-secret deployment identifiers and are loaded from
`backend/functions/.env.<firebase-project-id>` during deploy:

| Key | Description |
|---|---|
| `JCE_FUNCTIONS_REGION` | Firebase Functions deployment region |
| `JCE_DB_INSTANCE_CONNECTION_NAME` | Cloud SQL instance connection name |
| `JCE_DB_NAME` | PostgreSQL database name |
| `JCE_DB_USER` | PostgreSQL IAM database username |
| `JCE_FUNCTIONS_SERVICE_ACCOUNT` | Google service account used by deployed callables |

## Rules

- Never commit passwords, private keys, access tokens, or service-account JSON.
- Never hardcode production endpoints or branch identifiers.
- Keep Firebase client configuration environment-specific.
- Treat Firebase client API keys as identifiers, not server credentials.
- Use CI secret storage for signing material and deployment credentials.
- Demo authentication must remain disabled for staging and production builds.

## Build examples

```sh
flutter build apk \
  --dart-define=JCE_ENV=staging
```

Production builds use a gitignored per-platform file. Copy an example under
`config/`, validate it against the independently approved CI project ID, and
then pass the same file to Flutter:

```powershell
dart run tool/validate_release_config.dart `
  --config=config/production_android.local.json `
  --platform=android `
  --expected-project=$env:JCE_APPROVED_PRODUCTION_PROJECT_ID

flutter build appbundle `
  --release `
  --dart-define=JCE_APPROVED_PRODUCTION_PROJECT_ID=$env:JCE_APPROVED_PRODUCTION_PROJECT_ID `
  --dart-define-from-file=config/production_android.local.json
```

Do not put server/database/signing secrets in this file; dart defines are
recoverable from the client. See [release configuration](../config/README.md).

Staging web deployment uses the dedicated Hosting target so it cannot resolve
against the development or production project accidentally:

```sh
flutter build web \
  --release \
  --dart-define=JCE_ENV=staging \
  --dart-define=JCE_ENABLE_DEMO_AUTH=false

firebase deploy \
  --only hosting:staging-web \
  --project jce-pos-staging-259528
```

Production Hosting uses the separate `production-web` target and may only be
deployed after the production runbook and later security/release phases pass:

```powershell
firebase deploy `
  --only hosting:production-web `
  --project $env:JCE_APPROVED_PRODUCTION_PROJECT_ID
```

The same staging build is also published at the shorter public URL
`https://jce-pos.web.app`. The Hosting target is mapped explicitly in each
Firebase project, so the project flag remains mandatory:

```sh
firebase deploy \
  --only hosting:staging-web \
  --project jce-pos
```

For Android App Distribution, obtain the Android app ID from
`lib/firebase_options_staging.dart` and confirm it belongs to the staging
project before uploading:

```sh
firebase apps:list --project jce-pos-staging-259528

firebase appdistribution:distribute build/app/outputs/flutter-apk/app-release.apk \
  --app "$JCE_STAGING_ANDROID_APP_ID" \
  --project jce-pos-staging-259528 \
  --release-notes-file "$JCE_RELEASE_NOTES_FILE"
```

`firebase.json` records the default development client generated by
FlutterFire; its Android app ID is not the staging App Distribution target.
Keep the staging app ID and release-notes path in operator environment variables
or protected CI configuration.
