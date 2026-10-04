CREATE TABLE IF NOT EXISTS api_rate_limit_windows (
  identity_hash text NOT NULL,
  scope text NOT NULL,
  window_started_at timestamptz NOT NULL,
  request_count integer NOT NULL DEFAULT 1,
  expires_at timestamptz NOT NULL,
  PRIMARY KEY (identity_hash, scope, window_started_at),
  CONSTRAINT api_rate_limit_identity_hash_check
    CHECK (identity_hash ~ '^[a-f0-9]{64}$'),
  CONSTRAINT api_rate_limit_scope_check
    CHECK (scope ~ '^[a-z0-9_-]{1,80}$'),
  CONSTRAINT api_rate_limit_count_check
    CHECK (request_count > 0)
);

CREATE INDEX IF NOT EXISTS api_rate_limit_windows_expiry_idx
  ON api_rate_limit_windows (expires_at);

