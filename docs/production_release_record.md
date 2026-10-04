# Production release record

Copy this file for each release. Do not edit the template with real credentials
or customer data.

Release/version: PENDING  
Tag/commit: PENDING  
Change window/timezone: PENDING  
Release manager: Orlandone Estoce  
Client owner: Orlandone Estoce  
Incident primary: Orlandone Estoce  
Incident backup:  
Pilot scope: JCE Dry Goods Trading; Branch 1 and Branch 2; one register per
branch; Admin, Managers, and Cashiers/Staff. Protected organization, branch,
register, user, and device IDs remain PENDING and are not source constants.

## Scope

- Included changes: PENDING
- Excluded/deferred changes: PENDING
- Supported platform/minimum version: Android 10+ for POS/operations; latest two
  stable Chrome and Edge major versions for web administration/fallback; Windows
  production deferred by ADR-0001
- Known defects and approved exceptions: PENDING
- Feature flags and kill-switch state: PENDING

## Evidence

| Evidence | Result/reference |
| --- | --- |
| Format/analyze/unit/widget tests | PENDING |
| Backend type/security/unit tests | PENDING |
| End-to-end and fault-injection tests | PENDING |
| Migration 0001–0015 rehearsal/checksums | PENDING |
| Local schema 1–19 upgrade rehearsal | PENDING |
| Security/abuse/rate-limit tests | PENDING |
| Pilot performance/endurance | PENDING |
| Hardware and usability acceptance | PENDING |
| Reconciliation | PENDING |
| Backup/PITR restore and measured RPO/RTO | PENDING |
| Cost forecast/budget/cap review | Billing linked; project budget is USD 15 (approximately PHP 942 at configuration time), with 25/50/75/90/100% current-spend and 75% forecast alerts; recipient channel configured; SQL Connect trial active from 2026-09-16 with internal 2026-12-15 19:05 Asia/Manila decision/shutdown deadline; post-trial forecast and cap behavior PENDING |

## Artifacts and environment

| Item | Version/revision/SHA-256 |
| --- | --- |
| Android AAB/APK | PENDING |
| Web Hosting release | PENDING |
| Windows installer (only after ADR-0001 superseded) | DEFERRED |
| Functions revisions | PENDING |
| SQL Connect schema/connector | PENDING |
| Storage rules | PENDING |
| PostgreSQL migration state | PENDING |
| Local schema version | 19 |
| Previous rollback artifacts | PENDING |

## Communications and continuity

- Branch contacts/out-of-band channel: PENDING
- Maintenance notice: PENDING
- Offline/manual continuity instruction: PENDING
- Update cadence: PENDING
- Rollback decision deadline: PENDING

## Go/no-go approvals

| Role | Name | GO/NO-GO | Timestamp | Evidence/exception |
| --- | --- | --- | --- | --- |
| Release manager | Orlandone Estoce |  |  |  |
| Client owner | Orlandone Estoce |  |  |  |
| Backend/data owner | Orlandone Estoce |  |  |  |
| Security owner | Orlandone Estoce |  |  |  |
| QA owner | Efren Melencion |  |  |  |
| Branch operations owner | Julie Rose Estoce |  |  |  |
| Finance/billing owner | Julie Rose Estoce |  |  |  |

Final decision: NO-GO - infrastructure-only SQL Connect trial; no real data or
production release is authorized.
