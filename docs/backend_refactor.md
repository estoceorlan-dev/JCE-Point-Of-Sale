# Node.js/PostgreSQL refactor handoff

Updated: 2026-10-07 (Asia/Manila). Refactor Phases 1–2 have backend and native auth
components; the main Flutter transport switch remains Phase 4. This numbering is separate from the historical Firebase
production-readiness and feature-delivery phases.

## Baseline

The Flutter/Firebase checkpoint is
[`95efe28f45d35a966f01b2ee83b8b0a729ec7dc9`](https://github.com/estoceorlan-dev/JCE-Point-Of-Sale/commit/95efe28f45d35a966f01b2ee83b8b0a729ec7dc9).
It was pushed to `origin/main` before Phase 0 edits. All existing changes were
preserved. Root workspace files and both repositories also have local recovery
copies under `C:\JCE\.backups\refactor-phase-0-20261004-95efe28`.

Flutter analysis passed; 344 tests passed with one opt-in performance benchmark
skipped. Legacy Functions lint/build and all 94 tests passed. These are baseline
checks, not production approval or proof that the new API already supports POS.

## Canonical documents in the sibling backend repository

The standalone backend is published in the private
[JCE-Backend repository](https://github.com/estoceorlan-dev/JCE-Backend). Check it
out alongside this repository as `C:\JCE\jce_backend` for local development.

- [Full implementation plan](https://github.com/estoceorlan-dev/JCE-Backend/blob/main/docs/architecture_refactor_plan.md)
- [Baseline and verification](https://github.com/estoceorlan-dev/JCE-Backend/blob/main/docs/phase_0_baseline.md)
- [Firebase inventory and port map](https://github.com/estoceorlan-dev/JCE-Backend/blob/main/docs/firebase_migration_inventory.md)
- [Source manifest](https://github.com/estoceorlan-dev/JCE-Backend/blob/main/docs/phase_0_source_manifest.json)
- [Release compatibility](https://github.com/estoceorlan-dev/JCE-Backend/blob/main/docs/release_compatibility.md)

## Ownership and accepted behavior

Flutter retains presentation, domain use cases, Riverpod, SQLite, atomic local
writes, receipts/hardware, and `core/sync`. It gains provider-neutral identity,
device credentials, offline PIN enrollment, and HTTP data-source implementations.
The backend owns server authentication, authoritative migrations, server command
transactions, API contracts, and optional file/object storage.

Local and Render are alternative deployments. Devices must never redirect a
pending queue to another deployment. Branch/organization IDs and API origins stay
configurable, even for one branch. Images remain optional. Native Windows/Android
POS and web administration are the target; browser checkout stays disabled.

Existing Firebase transport, generated connectors, local SQLite schema 19, and
ADR-0001 production restrictions remain in force until their replacement phase
passes. Offline supervisor approval is currently unavailable; offline cashier PIN
work must not accidentally enable manager approvals.

## Current implementation and next phase

Phase 2 adds the native auth contracts under `features/auth/domain/offline`, HTTP
session/enrollment adapters, Windows/Android protected credential storage, signed
grant verification, persistent PIN lockouts, and cashier-switch rules. Separate
Riverpod providers require a verified `NativeAuthProfile`; the existing provider
remains Firebase until Phase 4. Web API sessions use protected cookies; the native
secure-storage adapter deliberately refuses web usage.

See the sibling backend's [Phase 2 guide](../../jce_backend/docs/phase_2_authentication.md)
and [verification report](../../jce_backend/docs/phase_2_verification.md). The backend
owns `docs/auth_openapi.json`; this repository keeps a copied public cryptographic
fixture and runs the live contract test when invoked by the backend integration suite.

Next is Phase 3: transactional commands, snapshots, synchronization and original
actor authorization. Main-app session/branch switching must use the existing shift
and recovery checks and preserve each queued operation's actor. Before offline
protected actions, call the native repository's `validateActive`; PIN login alone
does not authorize an expired session indefinitely. Physical Android security and
second-device WAN-disconnected acceptance remain pending.
