# Release configuration

Copy the platform example to a gitignored `*.local.json` file, replace every
placeholder with the isolated production Firebase client identifiers, then
validate it against the production project ID approved in the protected CI
environment. Firebase API keys in these files identify a client; they do not
replace App Check, authentication, authorization, or server-side rate limits.

```powershell
Copy-Item config/production_web.example.json config/production_web.local.json

dart run tool/validate_release_config.dart `
  --config=config/production_web.local.json `
  --platform=web `
  --expected-project=$env:JCE_APPROVED_PRODUCTION_PROJECT_ID

flutter build web `
  --release `
  --dart-define=JCE_APPROVED_PRODUCTION_PROJECT_ID=$env:JCE_APPROVED_PRODUCTION_PROJECT_ID `
  --dart-define-from-file=config/production_web.local.json
```

Use the Android example with `--platform=android` and `flutter build appbundle`.
Production Windows validation intentionally fails until ADR-0001 is superseded
by an implemented and approved transport/device-trust design.

Never add passwords, refresh tokens, service-account JSON, private keys, signing
keys, database URLs, or customer data to a dart-define file. Dart defines are
compiled into the client and must be treated as public.

Keep `JCE_APPROVED_PRODUCTION_PROJECT_ID` outside the JSON file. Protected CI
supplies it independently to both the validator and the Flutter build so startup
also rejects an accidentally selected production project.
