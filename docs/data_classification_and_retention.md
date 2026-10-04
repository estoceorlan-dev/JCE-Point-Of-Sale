# Data classification and retention register

Status: technical classification proposed; business/privacy/legal retention
approval pending.

Do not add real credentials, personal data, payment data, or customer records to
this document. Retention values remain `PENDING` until the business owner and
qualified Philippine privacy/tax counsel approve them.

| Data class | Examples | Sensitivity | Normal stores | Minimum access | Retention/deletion decision |
| --- | --- | --- | --- | --- | --- |
| Authentication secrets | Passwords, refresh/access tokens, private keys, signing keys | Restricted | Firebase/Identity provider, Secret Manager, OS secure store | Identity/runtime service only | PENDING; never application logs/backups by design |
| Employee identity | Name, email, Firebase UID, status | Confidential | Auth, PostgreSQL, scoped SQLite cache | Authorized staff admins and runtime | PENDING |
| Authorization | Organizations, assignments, roles, permission codes, device/register scope | Confidential | PostgreSQL, scoped SQLite cache, audit | Runtime and authorized admins | PENDING; preserve change evidence |
| Customer PII | Name, contact details, address, purchase association | Confidential | PostgreSQL and authorized device cache | Customer-authorized roles only | PENDING; support archive/anonymization obligations |
| Sales and payments | Sale lines, tender type/amount/reference, refund/correction | Restricted business | PostgreSQL, SQLite, receipt/audit | Cashier scope, managers, finance/reporting | PENDING; no card secrets/CVV storage |
| Inventory and purchasing | Products, costs, balances, counts, transfers, suppliers | Confidential business | PostgreSQL and branch-aware SQLite | Assigned operational roles | PENDING |
| Cash shifts | Float, cash movements, close counts, discrepancies | Restricted business | PostgreSQL and register/branch SQLite | Cashier owner and approved managers | PENDING |
| Audit/security evidence | Actor, action, device, before/after metadata, denials | Restricted | Append-only PostgreSQL/SQLite, monitoring | Security/audit-authorized roles | PENDING; immutable during approved period |
| Application logs | Error class, operation ID, pseudonymous scope, duration | Internal to restricted | Local bounded logs and cloud logging | Support/security | PENDING; exclude secrets and unnecessary PII |
| Local cache/outbox | Authorized projections, pending mutations, conflicts | Same as source data | Device SQLite/browser storage | Current device user/application | Until synchronized and policy permits cleanup; exact TTL PENDING |
| Backups | Database/logical backup copies | Restricted | Encrypted controlled backup location | Backup/recovery operators | PENDING; test expiry and deletion |
| Build/release evidence | Hashes, versions, test results, approvals | Internal | CI/release system | Engineering/audit | PENDING; contains no secrets or production data |

## Required controls

- Collect and cache only fields needed for the approved workflow.
- Preserve organization and branch scope through reads, writes, sync, exports,
  logs, backups, and support tools.
- Encrypt restricted/confidential data in transit and at rest. Local database
  encryption or a formally approved managed-device compensating control remains
  a production gate.
- Store application and signing secrets only in approved secret/credential
  stores. Dart defines and Firebase client API keys are public identifiers.
- Redact tokens, passwords, PINs, approval evidence, full contacts, and payment
  references from logs and errors.
- Clear safe-to-delete cached data on sign-out, reassignment, decommissioning, or
  retention expiry, but never delete unsynchronized business records blindly.
- Use anonymization/compensating records where immutable business history must be
  retained; do not rewrite financial or audit history in place.
- Document who can export data, maximum export scope, encryption, expiry, and
  deletion confirmation.
- Test restore and deletion, including backup copies and browser/device caches.

## Decisions required before production

- [ ] Record legal/tax retention for sales, receipts, corrections, inventory,
  purchasing, cash shifts, and audits.
- [ ] Record privacy retention and deletion/anonymization for customers/employees.
- [ ] Approve log, telemetry, crash, image, local-cache, and backup retention.
- [ ] Approve data residency and every third-party processor.
- [ ] Approve the lost/stolen device and remote decommissioning procedure.
- [ ] Approve evidence preservation rules during an incident or legal hold.

Business owner: PENDING  
Privacy/legal approver: PENDING  
Approved version/date: PENDING
