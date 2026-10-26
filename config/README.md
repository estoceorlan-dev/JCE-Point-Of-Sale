# Public Node client configuration

Use `node.local.example.json` for branch-local staging or `node.render.example.json`
for a separate hosted staging deployment. Copy to a gitignored `*.local.json` and
replace all placeholders using the trusted operator setup. See
[Node installation](../docs/node_installation.md). Node is the only supported backend.
Old Firebase profiles must be replaced; they are not silently converted.

For production Android/web candidates, use the corresponding production example.
Public verification keys are a JSON string keyed by `kid`, containing EC P-256
public JWKs. Never include a private `d`, passwords, session tokens, service-account
JSON, database URLs or signing secrets. Dart defines are public compiled data.
The API URL must be an HTTPS origin; web must be served from that same browser
origin. The Vercel deployment satisfies this with same-origin `/v1` and `/health`
rewrites to Render. Production web requires `JCE_ONLINE_ONLY=true`; native
production profiles require `JCE_ONLINE_ONLY=false`.

The independently approved deployment UUID belongs in protected CI settings,
not the JSON file. Supply it to the validator and build so startup also enforces it:

```powershell
dart run tool/validate_release_config.dart `
  --config=config/production_web.local.json `
  --platform=web `
  --expected-deployment=$env:JCE_APPROVED_PRODUCTION_DEPLOYMENT_ID

flutter build web --release --no-web-resources-cdn `
  --dart-define=JCE_APPROVED_PRODUCTION_DEPLOYMENT_ID=$env:JCE_APPROVED_PRODUCTION_DEPLOYMENT_ID `
  --dart-define-from-file=config/production_web.local.json
```

Use `--platform=android` and `flutter build appbundle` for Android, with a provisioned
release keystore. Windows production validation still fails until ADR-0001's physical
acceptance is completed. Passing the validator proves configuration shape and
approval matching, not service availability or production readiness.
