# Phase 8 synchronization engine

Phase 8 turns the Phase 7 remote command boundary into a restartable,
offline-first synchronization loop.

## Runtime behavior

Local mutations always commit their business records, audit entry, and owned
outbox command before any network work. A sync run then:

1. treats connectivity as a scheduling hint;
2. recovers stale `processing` records;
3. claims at most 25 aggregate heads at a time;
4. preserves order within an aggregate and pushes unrelated heads in parallel;
5. classifies success, retryable failure, permanent failure, or conflict;
6. pulls organization/branch changes after the stored cursor; and
7. applies each pull page and its cursor in one SQLite transaction.

The server change feed uses a versioned envelope containing the command type,
actor, original command payload, and authoritative result. Master-data writes
use the last accepted remote version. Inventory balances are replaced only by
the accepted server projection while immutable transactions and ledger entries
are appended idempotently.

## Triggers and platform support

- All platforms: manual sync, sign-in sync, connectivity regain, app resume,
  and a five-minute foreground timer.
- Android and iOS: Workmanager registers a network-constrained 15-minute
  periodic task. The operating system decides the actual execution time.
- macOS: Workmanager runs while the application is running or backgrounded;
  macOS does not continue this task after the app is quit.
- Windows and the web administration fallback: automatic foreground triggers
  are used because the selected native Workmanager package has no stable
  closed-app worker for these targets.

## Conflicts and diagnostics

The dashboard and app bar expose pending, retrying, failed, offline, and
conflicted states. Settings contains an administrator conflict panel with:

- **Retry local**, which requeues the same operation after accepted remote
  changes have been pulled; and
- **Accept remote**, which discards the blocked local command and keeps the
  server projection.

Rejected sales are changed to `sync_rejected`, remain in sales history, and
receive a conflict record. Sign-out warns when the active account owns pending
business data; another account cannot upload those commands.

## Deployment note

The updated Cloud Functions must be deployed together because new change-feed
rows use envelope schema version 1 and catalog commands now require optimistic
versions. Existing result-only change-feed rows are intentionally rejected by
the client instead of advancing the cursor with an incomplete projection.

## Staging rollout

Phase 8 was deployed to the isolated `jce-pos-staging-259528` project on
2026-08-27:

- Storage rules and all five Node 22 callable Functions are active at source
  hash `8881a84d1aabed7a0a8f80ff01daed407ea7d4c9`.
- Firebase client registrations were created for Android, Apple, web, and
  Windows. The client selects the staging registrations from
  `JCE_ENV=staging`; production remains fail-closed.
- Android release `1.0.0 (1)` was uploaded to Firebase App Distribution as
  release `1gnl0ied29f70`. Its SHA-256 digest is
  `6510EE497C4069AB72FDD472AA5039663E955A406C2143D136B385BA7EBCD42C`.
- An authenticated administrator smoke test loaded its access profile through
  Cloud SQL and reached the remote command authorization and dispatch path.
  The rollback-only probe returned the expected `INVALID_ARGUMENT` response,
  so it did not create staging business data.

Phase 8 does not add a PostgreSQL migration or Data Connect contract change;
the already-deployed Phase 7 schema remains current. The App Distribution
release has no tester group assigned automatically. The staging APK is signed
with the repository's current internal debug signing configuration and must not
be promoted as a production artifact.
