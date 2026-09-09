# Phase 7 validation and controlled rollout

Updated 2026-09-10. This document tracks the requested completion plan's Phase
7. It is separate from the repository's historical Phase 7 remote-backend
milestone.

## Current result

The first repeatable 10,000-product Windows measurement found that catalog text
search and barcode lookup missed the pilot targets by several seconds. Both
queries used a correlated barcode lookup without an index beginning with
`product_id`, causing repeated full scans of `product_barcodes`.

Drift schema 18 adds these local, non-destructive indexes:

- `product_barcodes_product_lookup_idx` on product, deletion state and normalized
  barcode.
- `product_prices_lookup_idx` on product, branch and effective date.

The schema-17-to-18 migration preserves catalog rows and verifies that both
indexes exist. This is a SQLite client migration only; it does not change the
authoritative PostgreSQL schema or any applied server migration checksum.

The opt-in benchmark uses a temporary file-backed SQLite database and the real
catalog import, product repository, POS search, outbox and checkout paths. It
creates 10,000 products, records JSON at `build/phase_7_performance.json`, and
removes its temporary database afterward.

```powershell
flutter test test/performance/phase_7_local_performance_test.dart `
  --dart-define=JCE_RUN_PHASE_7_PERFORMANCE=true `
  --dart-define=JCE_PERFORMANCE_PRODUCT_COUNT=10000 `
  --reporter expanded
```

## Local Windows measurement

Measured on 2026-09-10 using Windows 11 build 26200, 12 logical processors and
a file-backed Drift database on the development machine. These figures are
engineering evidence; they do not replace a run on the intended pilot terminal.

| Operation | Before schema 18 | After schema 18 | Pilot target | Local result |
| --- | ---: | ---: | ---: | --- |
| Exact barcode lookup, worst of 5 | 10,395.387 ms | 17.096 ms | < 200 ms | Pass |
| Text search, worst of 5 | 7,432.794 ms | 15.766 ms | < 500 ms | Pass |
| Atomic local checkout commit | 80.959 ms | 68.050 ms | < 1,000 ms | Pass |
| 10,000-row catalog preview | 480.667 ms | 500.828 ms | Record only | Measured |
| 10,000-row catalog commit | 41,446.881 ms | 36,973.744 ms | Record only | Measured |
| Pending count for 10,000 outbox rows | 217.690 ms | 22.843 ms | Record only | Measured |
| Claim 25 from 10,000 outbox rows | 237.175 ms | 265.066 ms | Record only | Measured |

CI now runs the backend security scan and TypeScript type check through
`npm run lint` in addition to the existing Flutter and Functions test suites.
The 10,000-row benchmark remains opt-in so shared CI runner variance cannot hide
or create pilot-hardware acceptance results.

## Controlled staging artifacts

Commit `38b8b1b` was built with `JCE_ENV=staging` and
`JCE_ENABLE_DEMO_AUTH=false` for Windows, Android and web. The schema-18 Android
APK is available in Firebase App Distribution as release `6bb3mf5vdh9k0`
without an assigned tester group. Its SHA-256 is
`29538012C1B4AC1C39BC066411C6CF546C0A12D0B991EF05E40CED2C559CAF1F`.

The Windows Release directory was built locally. The application payload at
`data/app.so` has SHA-256
`1C1872BC756AB86F9C26173296023352E2294AA5EEB9A84A56D009DAB9913E55`.
Copy the complete Release directory for pilot installation; it has not been
installed or accepted on the target terminal.

The matching web build is deployed to staging Hosting version
`815d116f50af2c5a`. Live `/` and `/branches` requests returned the Flutter shell,
JavaScript and WASM content types were correct, and the live `main.dart.js`
SHA-256 matched the local artifact:
`FE781A0FFCAACB76D3B4AA187C61629BCE49D2CBE303F12923EBD42665345405`.
No production environment or pilot flag was changed.

Deployment audit: the first upload command selected the default-project Android
app ID from `firebase.json` instead of the staging registration. It created an
unassigned release in the default development project. The release was verified
by ID and release notes and immediately removed with the App Distribution
`batchDelete` API. A subsequent API list confirmed that the default app has no
releases and the three documented staging releases are present. No tester or
group was assigned to the removed release.

The 2026-09-10 read-only staging database check reconfirmed that migrations
0001–0013 match their committed checksums, all 60 public tables remain owned by
`jce_pos_migrator`, normalized branch-code duplicate groups remain zero, and the
rollback-only shared/exclusive row-lock plus advisory-lock probes pass. It made
no business writes. The temporary human migration-role membership remains in
place because wider database concurrency acceptance is still open.

## Staging negative-test support

`staging-signed-in-check.js` can now require an existing active organization to
which the test administrator has no assignment. It verifies that both the
administration snapshot and a valid branch command are denied before a write.
The foreign organization ID is an explicit non-secret fixture identifier; the
runner rejects using the administrator's own organization.

```powershell
$env:JCE_FOREIGN_ORGANIZATION_ID='<approved-existing-staging-fixture-id>'
node backend/functions/scripts/staging-signed-in-check.js `
  --run --require-foreign-organization
```

The command still requires the staging-only environment and private credential
file described in `staging_acceptance_checkpoint.md`. It must not target
production. This expanded live check has not been run yet because an approved
existing foreign-organization fixture ID has not been recorded in the handoff.

## Remaining rollout gates

- Repeat the benchmark on the intended Windows pilot terminal using the complete
  Release directory and retain the generated JSON with the acceptance record.
- Run the required existing-foreign-organization staging check, limited-role
  accounts, last-administrator races and archive-versus-shift/count/transfer
  concurrency with approved fixtures.
- Complete two-device offline branch creation, restart, synchronization, access
  refresh and selection, plus offline cashier crash and held-cart scenarios.
- Complete invitation mismatch, expiry, reactivation and regeneration checks.
- Offline supervisor enrollment, secure credentials, lockout, signature and
  replay validation remain unavailable and fail closed. Do not enable an
  approval rollout flag until that implementation and physical Windows secure
  storage acceptance exist.
- Install and smoke-test the Windows and Android clients; complete physical
  scanner, printer and drawer failure acceptance after hardware is selected.
- Reconcile staging stock, sales, payments and shifts before enabling one pilot
  branch. Production and pilot flags remain unchanged.
- Remove the temporary human migration-role membership through the authorized
  PostgreSQL role administrator after all staging database work is complete.
