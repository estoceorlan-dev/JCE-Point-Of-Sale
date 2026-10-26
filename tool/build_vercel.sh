#!/usr/bin/env bash
set -euo pipefail

required=(
  JCE_PUBLIC_ORIGIN
  JCE_DEPLOYMENT_ID
  JCE_ORGANIZATION_CODE
  JCE_OFFLINE_VERIFICATION_KEYS
  JCE_APPROVED_PRODUCTION_DEPLOYMENT_ID
)
for name in "${required[@]}"; do
  if [[ -z "${!name:-}" ]]; then
    echo "$name is required for the hosted web build." >&2
    exit 64
  fi
done

flutter_version="${JCE_FLUTTER_VERSION:-3.44.9}"
cache_root="${VERCEL_CACHE_DIR:-.vercel-cache}"
flutter_root="$cache_root/flutter-$flutter_version"
if [[ ! -x "$flutter_root/bin/flutter" ]]; then
  if [[ -e "$flutter_root" ]]; then
    echo "Cached Flutter SDK is incomplete; clear only $flutter_root and rebuild." >&2
    exit 70
  fi
  git clone --depth 1 --branch "$flutter_version" \
    https://github.com/flutter/flutter.git "$flutter_root"
fi

"$flutter_root/bin/flutter" config --no-analytics >/dev/null
"$flutter_root/bin/flutter" pub get
"$flutter_root/bin/flutter" build web \
  --release \
  --no-web-resources-cdn \
  --no-source-maps \
  --dart-define=JCE_BACKEND=node \
  --dart-define=JCE_ENV=production \
  --dart-define=JCE_ENABLE_DEMO_AUTH=false \
  --dart-define=JCE_ENABLE_DIAGNOSTICS=false \
  --dart-define=JCE_ONLINE_ONLY=true \
  "--dart-define=JCE_API_BASE_URL=$JCE_PUBLIC_ORIGIN" \
  "--dart-define=JCE_DEPLOYMENT_ID=$JCE_DEPLOYMENT_ID" \
  "--dart-define=JCE_ORGANIZATION_CODE=$JCE_ORGANIZATION_CODE" \
  "--dart-define=JCE_OFFLINE_VERIFICATION_KEYS=$JCE_OFFLINE_VERIFICATION_KEYS" \
  "--dart-define=JCE_APPROVED_PRODUCTION_DEPLOYMENT_ID=$JCE_APPROVED_PRODUCTION_DEPLOYMENT_ID" \
  --dart-define=JCE_ALLOW_HTTP_LOOPBACK=false
