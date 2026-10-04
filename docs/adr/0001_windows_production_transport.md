# ADR-0001: Windows production transport

Date: 2026-09-15  
Status: accepted as an interim fail-closed safety decision; business launch
approval remains pending  
Decision owner: PENDING

## Context

JCE POS originally identifies Windows as the primary desktop POS target and uses
FlutterFire Authentication, callable Functions, and Storage. Current official
Firebase Flutter setup guidance cautions that Firebase on Windows is not intended
for production use cases. A shared secret embedded in a desktop application would
not be an acceptable replacement, and Android/web App Check providers do not by
themselves establish a production Windows trust boundary.

## Decision

The repository will fail closed for `JCE_ENV=production` on Windows. Windows stays
enabled in development and staging for ongoing pilot and hardware work.

The initial production candidate is:

- Android for POS/operational workflows;
- web for administration/operational fallback, with the POS route disabled.

Phase 3 will use Play Integrity for Android App Check and reCAPTCHA Enterprise
for web App Check, first in metrics mode and then enforced after staging
acceptance. These providers do not remove the need for Auth, RBAC, request
validation, idempotency, rate limits, or the Windows-specific decision above.

Production Windows can be enabled only by a later ADR after one of these paths is
implemented and accepted:

1. a vendor-supported Firebase/Flutter Windows production stack with an accepted
   attestation model; or
2. a supported HTTPS/API transport behind the existing repository interfaces,
   server-side Firebase/Identity Platform token verification, and unique revocable
   per-installation asymmetric credentials protected by Windows TPM/CNG where
   available.

No path may place a shared API secret, service-account credential, database
credential, or signing private key in the Windows binary.

## Required supersession evidence

- vendor/platform support review dated for the intended release;
- threat model covering token storage, device enrollment, replay, theft, cloning,
  revocation, rotation, clock skew, offline operation, and recovery;
- clean-architecture transport implementation and shared contract tests;
- server authorization remains authoritative for organization/branch/permission;
- per-request device proof bound to method, path, body digest, nonce, and timestamp;
- replay storage/expiry and emergency device revocation;
- penetration, abuse, load, offline, two-device, upgrade, and rollback evidence;
- security, operations, and release-owner approval.

## Consequences

- A production Windows build now stops on the controlled startup failure screen.
- Production configuration validation rejects `--platform=windows`.
- The production web navigation omits and rejects the POS route.
- Existing Windows staging behavior is unchanged.
- This reduces first-release platform scope but avoids representing a beta/unsupported
  dependency path as production-ready.

## Reference

- [Firebase for Flutter platform support](https://firebase.google.com/docs/flutter/setup)
