# Node.js/PostgreSQL refactor handoff

Updated: 2026-10-09 (Asia/Manila). Refactor Phases 3-4 implement the standalone
command/sync API and default Flutter Node transport. Physical acceptance remains
pending. This numbering is separate from historical Firebase delivery phases.

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

The explicit Firebase rollback transport and generated connectors remain until
Phase 7. The Node path uses deployment-specific SQLite schema 20 and signed
outbox evidence. ADR-0001 production restrictions remain in force; offline PINs
never authorize supervisor actions.

## Current implementation and next phase

Follow [Node installation](node_installation.md) for required Dart defines and
cashier enrollment. Riverpod selects HTTP authentication, commands, bootstrap,
snapshots and synchronization when `JCE_BACKEND=node` (the default). Browser
administration uses same-origin protected cookies; native installations use
protected P-256 credentials. Signed work retains its original actor after logout,
restart and cashier switching.

The backend owns [OpenAPI](../../jce_backend/docs/auth_openapi.json) and the
[signed protocol](../../jce_backend/docs/signed_sync_protocol.md). See
[Phase 3-4 verification](../../jce_backend/docs/phase_3_4_verification.md) for
checks, live Flutter/PostgreSQL sale evidence and remaining acceptance gates.

Next is Phase 5: remaining feature/UI parity, staff activation/recovery UI and
optional storage adapters. Native device builds, secure storage/reboot behavior,
trusted LAN HTTPS and second-device WAN-disconnected tests require physical
acceptance before production approval. Production packaging is Phase 6; Firebase
resource and SDK retirement is Phase 7.
