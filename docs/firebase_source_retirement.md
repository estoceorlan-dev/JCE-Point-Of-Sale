# Firebase source retirement

Date: 2026-10-11 (Asia/Manila). Prepared locally on explicit user instruction.
Node.js/PostgreSQL is now the only non-demo backend. Source cleanup is distinct
from production approval and cloud resource retirement.

## Changes

- Removed Firebase Auth/Core/App Check/Storage/Functions/Data Connect packages,
  generated connectors and FlutterFire/native configuration. Dependency resolution
  removed 24 packages including the six direct Firebase dependencies.
- Removed the legacy authentication, callable, image and device-registration
  adapters. Startup, background recovery, repositories and sync providers use Node.
  Demo startup remains available without credentials or an API profile.
- Retired `backend/`, `dataconnect/`, `.firebaserc`, `firebase.json`, storage rules
  and the embedded Functions CI job. Standalone `jce_backend` CI remains intact.
- Replaced Firebase production profiles/validation with public Node deployment
  profiles, independent approved deployment matching, HTTPS and public-key checks.
  Old `JCE_BACKEND=firebase` profiles are rejected. CI compiles Node web administration.
- Regenerated dependency locks and native plugin registrants. Updated current
  setup instructions and marked legacy deployment documents as historical.

SQLite schema 20, PostgreSQL migration 0024 and signed protocol 1 are unchanged.
Historical `firebase_uid`/`firebaseUid` storage fields and schema snapshots remain
for data compatibility; Node identity values occupy those fields. These names do
not import or contact Firebase. Existing local databases and queued sales are not
converted, erased or redirected by this cleanup. Node uses a deployment-specific
SQLite file; the development demo uses its own `jce_demo` file.

## Recovery checkpoint

`C:\JCE\.backups\firebase-retirement-20261011` contains:

- `jce_pos/` and `jce_backend/`: complete pre-edit tracked/nonignored working-source
  snapshots (1043 and 257 files), including the uncommitted Phase 7 preparation.
- `jce_pos.bundle` and `jce_backend.bundle`: verified complete Git history bundles.
- `jce_pos-files.json` and `jce_backend-files.json`: SHA-256 snapshot manifests.
- `workspace-AGENTS.md`: the prior workspace development rules.
- `retired-working-files/`: archived legacy trees, adapters, native config and
  ignored Firebase working/cache/local profile files, preserved outside the repo.

All 140 removed tracked files were checked byte-for-byte against the pre-edit
source snapshot. Pre-cleanup HEADs: Flutter `7e3614acf7aefdb6ef7f7ac24ceec634cfb1ba06` and backend
`d40add652e05cb2d96bb1b2a93fee5cc34795e14`. The original Firebase baseline remains
`95efe28f45d35a966f01b2ee83b8b0a729ec7dc9`. No commit or push is implied by this report.

Restore into a separate review directory from the source snapshots; use the
bundles for Git history. Copy ignored retired settings only when needed and handle
them as local configuration. A bundle alone does not contain uncommitted Phase 7
work. Do not point restored Firebase code at a Node deployment or reuse its queue.
These are source checkpoints, not database, object-storage or Auth exports.

## Verification

- Flutter dependency resolution: passed; Firebase packages removed from lockfile.
- Flutter analysis: passed with no issues after cleanup.
- Flutter unit/widget/repository suite: 354 passed, three opt-in tests skipped
  (two live API flows and the local performance benchmark).
- Startup/release regressions cover demo isolation, binding before recovery,
  rejected binding, web recovery exclusion, wrong deployment, legacy settings,
  unsafe production flags and private key material. A separate compiled `JCE_ENV=prod`
  check also confirms aliases cannot bypass independent deployment approval.
- Source/native/build input scan found no Firebase SDK imports or plugin registrations.
  Resolved package/plugin metadata, compiled web code, Windows artifact names and
  Android DEX/application-library scans also passed.
- Clean release builds passed for web, Windows and Android APK. The existing Android
  release-signing configuration was used; `apksigner verify` passed. All three
  builds use public **placeholder staging profiles** for compilation only. They
  require real provisioned profiles before use and are not production candidates.
- Both opt-in Flutter/Node/PostgreSQL contract flows passed after cleanup: online
  sign-in, enrollment proof and offline PIN sign-in; and offline SQLite checkout,
  reopen, then exactly-once upload without a cashier session. The isolated runner
  used `-TestNamePattern 'Flutter'`; other integration scenarios were not rerun.
  Backend TypeScript build passed as part of this run.
- Release-validator CLI accepted a public fixture profile. Targeted final profile
  analysis and formatting checks passed.

The initial incremental web build encountered an old generated Firebase plugin
registrant. `flutter clean` and fresh dependency resolution removed cached build
inputs before the successful clean compilation. Outputs are `build/web`,
`build/windows/x64/runner/Release`, and `build/app/outputs/flutter-apk/app-release.apk`.

The first live-test invocation stalled on redirected process output after creating
its isolated database; it was interrupted and its server is confirmed stopped.
Rerunning in a console session completed both flows and removed that run's cluster.
Automatic approval review rejected cleanup of the first stopped cluster with
"blocked by policy." Its files remain in the backend's ignored directory
`.tmp/postgres-a762c7c566064f9fb8244a14dce39c9b`; no server is running for it.

## Remaining release and cloud gates

No Render deployment or Firebase cloud resource deletion occurred. The filtered
cloud inventory still represents live resources; full Cloud SQL/object/Auth/IAM/
billing inventory and protected export/read-back remain outstanding. Follow
[cloud retirement](../../jce_backend/docs/firebase_retirement.md).

No physical Android device is attached. Real secure-storage, PIN enrollment,
installation/reboot, printers, two-device disconnected-WAN and replacement-server
restore acceptance remain required. Windows production remains blocked under
ADR-0001; browser checkout remains disabled. Source removal and successful local
checks do not approve a production deployment.
