# JCE POS

Offline-first Flutter POS for multiple branches, with a standalone Node.js API
and PostgreSQL server in the sibling `jce_backend` repository. Windows and Android
are the POS targets; web is administration only.

Firebase SDKs, adapters, generated connectors, configuration and the embedded
legacy backend have been removed. `JCE_BACKEND=firebase` is rejected. See the
[source retirement record](docs/firebase_source_retirement.md) for the recovery
checkpoint, verification and remaining deployment gates.

## Getting started

The hosted web administration build is an explicitly online-only profile. Vercel
serves the bundle and same-origin proxies API traffic to Render; local Windows and
Android deployments retain the existing offline-first behavior. See the backend
[Vercel + Render guide](../jce_backend/docs/vercel_render_free_deployment.md).

Follow [Node installation](docs/node_installation.md) to provision the backend,
configure the API origin/deployment UUID/public verification keys, and enroll a
cashier PIN. Copy `config/node.local.example.json` to an ignored
`config/node.local.json` and replace the placeholders before running:

```powershell
flutter pub get
flutter run -d windows --dart-define-from-file=config/node.local.json
```

For a development-only demo without a server:

```powershell
flutter run -d windows --dart-define=JCE_ENV=development --dart-define=JCE_ENABLE_DEMO_AUTH=true --dart-define=JCE_DEMO_BRANCH_ID=demo-main
```

A deployment has one authoritative database. Branch-local operation uses LAN
connectivity without internet; Render is an independent hosted deployment.
Clients never connect directly to PostgreSQL. SQLite-first writes and signed
outbox operations survive outages and restarts. Offline PIN sign-in requires
prior enrollment on that device and unexpired authorization. Product images are
optional and never block checkout or core sync.

The canonical bundle identifier is `com.jce.pos`. Linux, macOS and iOS scaffolds
are retained for evaluation, not approved production targets. Windows production
remains blocked under [ADR-0001](docs/adr/0001_windows_production_transport.md).
Physical device, hardware, disconnected-WAN and restore acceptance remain pending.
Local source cleanup does not approve a production deployment or delete cloud data.

## Development

Follow [AGENTS.md](AGENTS.md) and the [backend refactor handoff](docs/backend_refactor.md).
Features use clean architecture, Riverpod, repository contracts and typed results.
The dedicated `core/sync` module owns upload, download and conflict resolution.

```powershell
dart format --output=none --set-exit-if-changed lib test integration_test tool
flutter analyze
flutter test
```

Backend validation runs in `jce_backend` with its own CI. See that repository's
README for Node/PostgreSQL commands and local/Render deployment runbooks.
[Public release configuration](config/README.md) describes production validation.
Historical `docs/phase_*` and Firebase deployment documents preserve earlier
implementation evidence; their Firebase deployment commands are retired.

Drift schema snapshots remain immutable. For intentional model changes:

```powershell
dart run build_runner build --delete-conflicting-outputs --low-resources-mode
```

Increment the released schema version and use `dart run drift_dev make-migrations`
for database changes. This source retirement leaves SQLite schema 20 unchanged.
After a Drift upgrade regenerate `web/drift_worker.js` with
`dart compile js web/drift_worker.dart -O4 -o web/drift_worker.js`.
