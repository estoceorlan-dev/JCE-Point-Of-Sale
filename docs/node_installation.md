# Node/PostgreSQL client installation

Phase 3–4 implementation, 2026-10-09. The default `JCE_BACKEND` is now `node`.
Use the standalone `../jce_backend` repository; the embedded Firebase backend is
retained only for the explicit `JCE_BACKEND=firebase` rollback path.

1. Provision an empty dedicated PostgreSQL database with the backend operator
   commands and apply migrations through 0022. Enable authentication, create its
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

The Node path skips Firebase initialization and product-image upload processing.
Images remain optional; the old image adapter and staff invitation-link UI are
Phase 5 parity work. Staff activation/recovery uses the backend's one-time token
workflow. These features do not silently fall back to Firebase.

Windows production remains blocked by ADR-0001 pending real device acceptance.
The automated SQLite/API sale test is not proof of physical Android secure storage,
Windows installer/reboot, printers, trusted LAN TLS, or two-device operation with
the router WAN disconnected. Do those checks before approving production.
