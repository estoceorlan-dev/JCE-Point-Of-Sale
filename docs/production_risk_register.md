# Production risk register

Status: open; initial owners partly assigned, with remaining risk assignments,
named backup ownership, and privacy/legal ownership still pending.

| ID | Risk | Impact | Required treatment | State | Owner |
| --- | --- | --- | --- | --- | --- |
| R-001 | Firebase Flutter Windows is not currently presented as a production-supported path by vendor guidance | Unsupported primary POS dependency and incomplete device attestation | ADR-0001 defers Windows; implement and test an approved transport/device-trust replacement before enabling | Mitigated by fail-closed gate; open | Orlandone Estoce (Security) |
| R-002 | Production Storage is absent and SQL remains infrastructure-only | Production cannot initialize Storage or sync | Provision Storage and authorize/harden the data path only after governance approval; obtain a passing preflight | SQL trial infrastructure exists; Storage/data path open | Julie Rose Estoce (Billing), Orlandone Estoce (Backend/data) |
| R-003 | Plaintext `C:/JCE/credentials.md` exists outside the repository | Secret compromise if active values are present | Inventory without copying, migrate to approved manager, rotate, confirm recovery, securely remove plaintext | Open; content not inspected | Orlandone Estoce (Security) |
| R-004 | Android release uses debug signing and Windows has no signed installer flow | Artifact impersonation, upgrades fail, store rejection | Implement protected production signing in Phase 9; never promote current staging APK | Open | Orlandone Estoce (Release/client) |
| R-005 | No automated end-to-end suite exists | Cross-layer regressions may escape unit/widget tests | Implement isolated Auth/Functions/PostgreSQL/SQLite integration tests | Open | Efren Melencion (QA) |
| R-006 | App Check, rate limits, and Functions runtime caps are absent | Abuse, database exhaustion, unexpected spend | Implement Phase 3–4 controls and load/abuse tests | Open | Orlandone Estoce (Security/backend) |
| R-007 | SQLite/cache encryption is not implemented | Lost/shared device may expose business/PII data | Implement encryption or approve managed-device compensating controls | Open | PENDING |
| R-008 | Offline supervisor cryptographic approval is unimplemented | Insecure local approval shortcut could bypass policy | Keep unavailable/fail-closed; never replace with typed ID/plain PIN | Controlled; open feature | PENDING |
| R-009 | Three moderate transitive `qs`/Express audit findings were observed on 2026-09-15 | Denial-of-service exposure | Upgrade/test dependency or approve short time-bound exception | Open | PENDING |
| R-010 | Production crash/performance/cost observability is incomplete | Slow detection and recovery | Implement dashboards, alerts, redaction, runbooks, and game day | Open | PENDING |
| R-011 | Temporary human staging migration-role membership is documented as still present | Excess standing privilege | Authorized role administrator revokes after migration work and records verification | Open | PENDING |
| R-012 | Browser storage is accessible to the signed-in OS/browser profile | Web cache may expose sensitive offline data | Web is admin fallback, production POS route disabled; define cache minimization/clear policy | Partially mitigated; open | PENDING |
| R-013 | Production retention/privacy/tax decisions are not approved | Noncompliance or premature/excessive deletion | Approve the classification and retention register with qualified owners | Open | PENDING |
| R-014 | Function connector currently requests public IP | Wider network exposure than a private path | Evaluate private IP/VPC; document accepted network boundary and latency/cost | Open | PENDING |
| R-015 | Production runtime identity had project-level `roles/storage.objectAdmin` | A compromised runtime could modify every bucket object in the project | Project-level grant removed; later grant only required permissions on the production bucket | Resolved at project scope 2026-09-15; bucket grant pending | PENDING |
| R-016 | Firebase CLI identity inspection printed cached OAuth credentials to tool output | Credential disclosure | Firebase logout revoked the refresh token immediately; require fresh login and avoid token-bearing CLI JSON output | Closed 2026-09-15 | Security review pending |
| R-017 | Flutter warns that Gradle 8.12, AGP 8.9.1, and Kotlin 2.1.0 are nearing support removal | Future Android builds may stop working after a Flutter upgrade | Upgrade the Android toolchain together and run the full Android regression/build matrix before release | Open | PENDING |
| R-018 | The pilot selected zonal Cloud SQL rather than regional HA | A zonal outage can interrupt central sync and administration until recovery | Keep POS offline continuity available, enable backups/PITR/deletion protection, rehearse restore, limit rollout to the named pilot, and require a new availability decision before expansion | Open; accepted only as pilot design, not broad production approval | Orlandone Estoce (Backend/data), Julie Rose Estoce (Operations) |
| R-019 | The PHP 1,000 monthly envelope relies on the temporary default SQL Connect Cloud SQL trial | The observed default disables backups/PITR and deletion protection; configuration changes can end the trial and standard pricing may exceed the envelope | Use the untouched default only for isolated testing with no production data, monitor the USD 15 budget, and approve a protected paid tier or shutdown plan before production | Trial active from 2026-09-16; internal decision/shutdown deadline 2026-12-15 19:05 Asia/Manila; protected-tier decision open | Julie Rose Estoce (Billing), Orlandone Estoce (Backend/data) |

## Risk acceptance rule

No Severity 0/1, cross-tenant, financial-integrity, unsupported-platform, signing,
backup, or plaintext-secret risk may be waived by a single engineer. An accepted
risk needs the security owner, affected business owner, release manager, expiry
date, compensating controls, and tracked remediation.
