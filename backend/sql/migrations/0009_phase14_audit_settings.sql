BEGIN;

ALTER TABLE audit_logs ADD COLUMN IF NOT EXISTS device_id text;

CREATE TABLE IF NOT EXISTS organization_settings (
  id text PRIMARY KEY,
  organization_id text NOT NULL REFERENCES organizations(id) ON DELETE RESTRICT,
  setting_key text NOT NULL,
  value_json jsonb NOT NULL,
  version integer NOT NULL DEFAULT 0 CHECK (version >= 0),
  updated_by_user_id text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (organization_id, setting_key),
  UNIQUE (id, organization_id),
  FOREIGN KEY (updated_by_user_id, organization_id)
    REFERENCES app_users(id, organization_id) ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS branch_settings (
  id text PRIMARY KEY,
  organization_id text NOT NULL REFERENCES organizations(id) ON DELETE RESTRICT,
  branch_id text NOT NULL,
  setting_key text NOT NULL,
  value_json jsonb NOT NULL,
  version integer NOT NULL DEFAULT 0 CHECK (version >= 0),
  updated_by_user_id text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (organization_id, branch_id, setting_key),
  UNIQUE (id, organization_id, branch_id),
  FOREIGN KEY (branch_id, organization_id)
    REFERENCES branches(id, organization_id) ON DELETE RESTRICT,
  FOREIGN KEY (updated_by_user_id, organization_id)
    REFERENCES app_users(id, organization_id) ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS number_sequences (
  id text PRIMARY KEY,
  organization_id text NOT NULL REFERENCES organizations(id) ON DELETE RESTRICT,
  branch_id text,
  branch_scope text NOT NULL,
  sequence_key text NOT NULL,
  prefix text NOT NULL DEFAULT '',
  next_value bigint NOT NULL DEFAULT 1 CHECK (next_value >= 1),
  padding integer NOT NULL DEFAULT 6 CHECK (padding BETWEEN 1 AND 12),
  version integer NOT NULL DEFAULT 0 CHECK (version >= 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (organization_id, branch_scope, sequence_key),
  FOREIGN KEY (branch_id, organization_id)
    REFERENCES branches(id, organization_id) ON DELETE RESTRICT,
  CHECK ((branch_id IS NULL AND branch_scope = '*') OR
         (branch_id IS NOT NULL AND branch_scope = branch_id))
);

CREATE TABLE IF NOT EXISTS reason_codes (
  id text PRIMARY KEY,
  organization_id text NOT NULL REFERENCES organizations(id) ON DELETE RESTRICT,
  branch_id text,
  branch_scope text NOT NULL,
  category text NOT NULL,
  code text NOT NULL,
  label text NOT NULL,
  requires_note boolean NOT NULL DEFAULT false,
  is_active boolean NOT NULL DEFAULT true,
  sort_order integer NOT NULL DEFAULT 0,
  version integer NOT NULL DEFAULT 0 CHECK (version >= 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz,
  UNIQUE (organization_id, branch_scope, category, code),
  UNIQUE (id, organization_id),
  FOREIGN KEY (branch_id, organization_id)
    REFERENCES branches(id, organization_id) ON DELETE RESTRICT,
  CHECK ((branch_id IS NULL AND branch_scope = '*') OR
         (branch_id IS NOT NULL AND branch_scope = branch_id))
);

CREATE TABLE IF NOT EXISTS feature_flags (
  id text PRIMARY KEY,
  organization_id text NOT NULL REFERENCES organizations(id) ON DELETE RESTRICT,
  branch_id text,
  branch_scope text NOT NULL,
  flag_key text NOT NULL,
  is_enabled boolean NOT NULL DEFAULT false,
  configuration_json jsonb NOT NULL DEFAULT '{}'::jsonb,
  version integer NOT NULL DEFAULT 0 CHECK (version >= 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (organization_id, branch_scope, flag_key),
  UNIQUE (id, organization_id),
  FOREIGN KEY (branch_id, organization_id)
    REFERENCES branches(id, organization_id) ON DELETE RESTRICT,
  CHECK ((branch_id IS NULL AND branch_scope = '*') OR
         (branch_id IS NOT NULL AND branch_scope = branch_id))
);

CREATE INDEX IF NOT EXISTS organization_settings_key_idx
  ON organization_settings (organization_id, setting_key);
CREATE INDEX IF NOT EXISTS branch_settings_key_idx
  ON branch_settings (organization_id, branch_id, setting_key);
CREATE INDEX IF NOT EXISTS number_sequences_scope_idx
  ON number_sequences (organization_id, branch_scope, sequence_key);
CREATE INDEX IF NOT EXISTS reason_codes_scope_idx
  ON reason_codes (organization_id, branch_scope, category, code);
CREATE INDEX IF NOT EXISTS feature_flags_scope_idx
  ON feature_flags (organization_id, branch_scope, flag_key);
CREATE INDEX IF NOT EXISTS audit_logs_operation_idx
  ON audit_logs (organization_id, operation_id);

CREATE OR REPLACE FUNCTION reject_audit_log_mutation()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  RAISE EXCEPTION 'audit_logs is append-only' USING ERRCODE = '55000';
END;
$$;

DROP TRIGGER IF EXISTS audit_logs_no_update ON audit_logs;
CREATE TRIGGER audit_logs_no_update
BEFORE UPDATE ON audit_logs
FOR EACH ROW EXECUTE FUNCTION reject_audit_log_mutation();

DROP TRIGGER IF EXISTS audit_logs_no_delete ON audit_logs;
CREATE TRIGGER audit_logs_no_delete
BEFORE DELETE ON audit_logs
FOR EACH ROW EXECUTE FUNCTION reject_audit_log_mutation();

COMMIT;
