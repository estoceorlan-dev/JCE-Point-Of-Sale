# Node/PostgreSQL client installation

Updated 2026-10-11. The only supported backend is the standalone `../jce_backend`
Node.js/PostgreSQL API. The Firebase runtime and embedded backend are retired;
see [source retirement](firebase_source_retirement.md) for the archived checkpoint.

1. Provision an empty dedicated PostgreSQL database with the backend operator
   commands and apply migrations through 0024. Enable authentication, create its
   signing key, and configure the API's trusted HTTPS origin. Keep PostgreSQL and
   private signing/database credentials on the server.
2. Copy `config/node.local.example.json` to `config/node.local.json` (ignored by Git).
   Enter the deployment UUID reported by provisioning, organization code, HTTPS API
   origin, and public verification key from the trusted server setup. The key map
   is a JSON **string** keyed by `kid`. Never put private JWK fields or database
   credentials in a Flutter define file.
3. Run `flutter run -d windows --dart-define-from-file=config/node.local.json` for
   staging validation. Use the same file with an Android device. For same-machine
   development only, HTTP `127.0.0.1`/`localhost` requires explicit loopback allowances
   in both client and server. Android's emulator alias or a LAN IP is not loopback.
4. Sign in with the provisioned account and claim a register. First sign-in binds
   the first authorized branch returned by the API; provision branch access accordingly. An installation is bound to one branch. Register reassignment
   uses the audited manager workflow; changing branches needs an explicit future
   installation migration rather than changing local metadata.
5. Use the **Offline cashier PIN** action in the top bar to enroll a 6–12 digit PIN
   using the account password. Cashiers must each enroll on this device while the
   API is reachable. On the login page choose **Sign in with an offline PIN** when
   the API is unavailable. Expired/locked enrollments require online recovery.
6. **Switch cashier** checks shift/payment recovery and preserves signed pending
   work. Full logout retains its stricter queue checks. Reopening the app also
   attempts device-only queue recovery without restoring a cashier. Android's
   scheduled worker uploads without rotating cashier session tokens.

Use `node.render.example.json` for a separate hosted installation, with its own
deployment ID and key. There is no automatic LAN/cloud failover. To change only the
address of the same database, install the updated profile while online and verify
the same deployment/key. Offline startup is allowed only at a previously verified
origin. Fresh deployment state never reuses the legacy Firebase SQLite file.

Browser administration uses a same-origin HTTPS frontend/reverse proxy and Secure
HttpOnly cookies. Only non-secret deployment/profile metadata goes into browser
storage. No device private key, bearer token, PIN, or offline enrollment is stored
there. Web checkout stays disabled in every Node environment.

The client uses an optional image queue
and staff activation/recovery token workflow. Image failure does not block checkout
or core sync.

Windows production remains blocked by ADR-0001 pending real device acceptance.
The automated SQLite/API sale test is not proof of physical Android secure storage,
Windows installer/reboot, printers, trusted LAN TLS, or two-device operation with
the router WAN disconnected. Do those checks before approving production.

## Phase 5-6 update (2026-10-10)

The Node client includes optional private image upload/retrieval and account
activation/recovery. New installation checks require API major 1 / PostgreSQL
migration 0024 and reject a server with `recoveryRequired:true` while preserving
local queues. API 1.1.0 keeps signed command protocol 1 and SQLite schema 20.

For local HTTPS, `JCE_TLS_CA_CERT_BASE64` contains only the operator-verified public
Caddy root certificate. The native HTTP adapter extends normal trusted roots and
retains hostname/expiry verification on Windows and Android. Android's main manifest
includes INTERNET for LAN sockets. Browser administration uses browser certificate
trust and same-origin cookie/CSRF handling. Deploy the compatible server/schema
before clients; preserve the deployment ID and signing key.

Operator source runbooks are in `jce_backend/docs/local_production_package.md` and
`backup_restore.md`. Native signed installers, physical reboot/hardware/Wi-Fi tests
and the Windows production gate remain pending. Cloud retirement remains separate.

## Phase 7 hosted preparation (2026-10-11)

The backend now has separate staging/production Render Blueprints, a same-origin
web artifact packager/server and an isolated migration release workflow. Follow
`jce_backend/docs/render_deployment.md`. Build with
`flutter build web --release --no-web-resources-cdn --dart-define-from-file=config/node.render.local.json`
using an actual provisioned profile, not the example placeholders. Keep the profile
out of version control and include only public client settings. The API URL must
equal the origin serving web administration for cookies and CSRF to work.

No hosted deployment or cloud resource retirement was performed. Firebase source
retirement is recorded separately. Physical
device and recovery acceptance is still required. This phase retains the existing
Windows gate and web checkout restriction. API 1.1.0/schema 24/SQLite 20 remain
compatible; server metadata reports release `node-refactor-phase-7`.
