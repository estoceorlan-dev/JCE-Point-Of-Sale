# Environment configuration

The supported runtime is the standalone Node.js API. `JCE_BACKEND` defaults to
`node`; other values are rejected. Follow [Node installation](node_installation.md)
and [release configuration](../config/README.md) for complete profiles and commands.

- `JCE_ENV`: development, staging or production; required in protected builds.
- `JCE_ENABLE_DEMO_AUTH`: development-only, opt-in. Requires `JCE_DEMO_BRANCH_ID`.
- `JCE_ENABLE_DIAGNOSTICS`: must be false in production.
- `JCE_API_BASE_URL`: trusted API origin, HTTPS for deployments.
- `JCE_DEPLOYMENT_ID`: stable database/deployment UUID used for client binding.
- `JCE_ORGANIZATION_CODE`: provisioned organization selector.
- `JCE_OFFLINE_VERIFICATION_KEYS`: JSON string containing pinned public P-256 JWKs.
- `JCE_TLS_CA_CERT_BASE64`: optional trusted public LAN CA certificate for native clients.
- `JCE_ALLOW_HTTP_LOOPBACK`: same-machine development only, false in production.
- `JCE_APPROVED_PRODUCTION_DEPLOYMENT_ID`: independent protected build input;
  must match the production profile and must not be in its JSON file.

Keep profiles for local and hosted databases separate. Changing an address requires
verification against the same deployment and pinned key. Offline startup requires
a previously bound origin. No automatic database failover is implemented.

Firebase project IDs, App Check keys, callable names and generated options are
retired. Old Firebase data and queues are not migrated by changing a profile.
Historical schema column names remain for compatibility; they do not load an SDK.
