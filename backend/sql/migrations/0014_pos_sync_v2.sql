-- Windows-first POS synchronization and installation-owned register claims.
-- This migration is additive so the preceding client/server versions continue
-- to operate while pos_sync_v2 is being enabled.

INSERT INTO permissions (code, name, description, created_at, updated_at)
VALUES (
  'registers.claim',
  'Claim registers',
  'Claim an active unassigned register for the current POS installation.',
  now(),
  now()
)
ON CONFLICT (code) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  updated_at = now();

-- Preserve the behavior of existing roles. New roles remain explicitly
-- configurable because this is a one-time migration grant.
INSERT INTO role_permissions (role_id, permission_code, granted_at)
SELECT rp.role_id, 'registers.claim', now()
FROM role_permissions rp
WHERE rp.permission_code = 'sales.process'
ON CONFLICT (role_id, permission_code) DO NOTHING;

ALTER TABLE devices
  ADD COLUMN IF NOT EXISTS registered_by_user_id text,
  ADD COLUMN IF NOT EXISTS last_seen_by_user_id text;

UPDATE devices
SET registered_by_user_id = COALESCE(registered_by_user_id, user_id),
    last_seen_by_user_id = COALESCE(last_seen_by_user_id, user_id)
WHERE registered_by_user_id IS NULL OR last_seen_by_user_id IS NULL;

-- `user_id` remains as a nullable compatibility projection for older clients;
-- it is no longer the owner of the installation and is never changed during
-- account switching.
ALTER TABLE devices
  DROP CONSTRAINT IF EXISTS devices_user_organization_fk,
  ALTER COLUMN user_id DROP NOT NULL;

ALTER TABLE devices
  ADD CONSTRAINT devices_registered_by_user_organization_fk
  FOREIGN KEY (registered_by_user_id, organization_id)
  REFERENCES app_users(id, organization_id) ON DELETE RESTRICT;

ALTER TABLE devices
  ADD CONSTRAINT devices_last_seen_by_user_organization_fk
  FOREIGN KEY (last_seen_by_user_id, organization_id)
  REFERENCES app_users(id, organization_id) ON DELETE RESTRICT;

CREATE TABLE IF NOT EXISTS register_claims (
  id text PRIMARY KEY,
  organization_id text NOT NULL REFERENCES organizations(id) ON DELETE RESTRICT,
  branch_id text NOT NULL,
  requested_register_id text NOT NULL,
  resolved_register_id text,
  device_id text NOT NULL,
  claimed_by_user_id text NOT NULL,
  status text NOT NULL CHECK (
    status IN ('accepted', 'rejected', 'resolved', 'released')
  ),
  rejection_code text,
  rejection_message text,
  resolution_operation_id text,
  resolved_by_user_id text,
  resolved_at timestamptz,
  released_by_user_id text,
  released_at timestamptz,
  version integer NOT NULL DEFAULT 0 CHECK (version >= 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (id, organization_id, branch_id),
  UNIQUE (organization_id, resolution_operation_id),
  FOREIGN KEY (branch_id, organization_id)
    REFERENCES branches(id, organization_id) ON DELETE RESTRICT,
  FOREIGN KEY (requested_register_id, organization_id, branch_id)
    REFERENCES registers(id, organization_id, branch_id) ON DELETE RESTRICT,
  FOREIGN KEY (resolved_register_id, organization_id, branch_id)
    REFERENCES registers(id, organization_id, branch_id) ON DELETE RESTRICT,
  FOREIGN KEY (organization_id, device_id)
    REFERENCES devices(organization_id, id) ON DELETE RESTRICT,
  FOREIGN KEY (claimed_by_user_id, organization_id)
    REFERENCES app_users(id, organization_id) ON DELETE RESTRICT,
  FOREIGN KEY (resolved_by_user_id, organization_id)
    REFERENCES app_users(id, organization_id) ON DELETE RESTRICT,
  FOREIGN KEY (released_by_user_id, organization_id)
    REFERENCES app_users(id, organization_id) ON DELETE RESTRICT
);

CREATE UNIQUE INDEX IF NOT EXISTS register_claims_active_device_uidx
  ON register_claims (organization_id, device_id)
  WHERE status IN ('accepted', 'resolved');

CREATE UNIQUE INDEX IF NOT EXISTS register_claims_active_register_uidx
  ON register_claims (
    organization_id,
    COALESCE(resolved_register_id, requested_register_id)
  )
  WHERE status IN ('accepted', 'resolved');

CREATE INDEX IF NOT EXISTS register_claims_unresolved_idx
  ON register_claims (organization_id, branch_id, status, created_at)
  WHERE status = 'rejected';

CREATE INDEX IF NOT EXISTS register_claims_device_history_idx
  ON register_claims (organization_id, device_id, created_at DESC);

CREATE TABLE IF NOT EXISTS manager_action_grants (
  id text PRIMARY KEY,
  organization_id text NOT NULL REFERENCES organizations(id) ON DELETE RESTRICT,
  branch_id text NOT NULL,
  requested_by_user_id text NOT NULL,
  manager_user_id text NOT NULL,
  action text NOT NULL CHECK (action = 'register.claim.resolve'),
  conflict_id text NOT NULL,
  target_register_id text NOT NULL,
  device_id text NOT NULL,
  nonce_hash text NOT NULL,
  expires_at timestamptz NOT NULL,
  consumed_at timestamptz,
  consumed_by_operation_id text,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (organization_id, nonce_hash),
  FOREIGN KEY (branch_id, organization_id)
    REFERENCES branches(id, organization_id) ON DELETE RESTRICT,
  FOREIGN KEY (conflict_id, organization_id, branch_id)
    REFERENCES register_claims(id, organization_id, branch_id) ON DELETE RESTRICT,
  FOREIGN KEY (target_register_id, organization_id, branch_id)
    REFERENCES registers(id, organization_id, branch_id) ON DELETE RESTRICT,
  FOREIGN KEY (organization_id, device_id)
    REFERENCES devices(organization_id, id) ON DELETE RESTRICT,
  FOREIGN KEY (requested_by_user_id, organization_id)
    REFERENCES app_users(id, organization_id) ON DELETE RESTRICT,
  FOREIGN KEY (manager_user_id, organization_id)
    REFERENCES app_users(id, organization_id) ON DELETE RESTRICT
);

CREATE INDEX IF NOT EXISTS manager_action_grants_expiry_idx
  ON manager_action_grants (organization_id, expires_at)
  WHERE consumed_at IS NULL;

-- The legacy projection used to be unique only inside a branch. Fail loudly
-- if production data must be repaired before installing the organization-wide
-- invariant.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM registers
    WHERE assigned_device_id IS NOT NULL AND deleted_at IS NULL
    GROUP BY organization_id, assigned_device_id
    HAVING count(*) > 1
  ) THEN
    RAISE EXCEPTION
      'duplicate active register assignments must be repaired before migration 0014';
  END IF;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS registers_one_active_installation_uidx
  ON registers (organization_id, assigned_device_id)
  WHERE assigned_device_id IS NOT NULL AND deleted_at IS NULL;

ALTER TABLE shifts ADD COLUMN IF NOT EXISTS register_claim_id text;
ALTER TABLE cash_movements ADD COLUMN IF NOT EXISTS register_claim_id text;
ALTER TABLE sales ADD COLUMN IF NOT EXISTS register_claim_id text;

ALTER TABLE shifts
  ADD CONSTRAINT shifts_register_claim_fk
  FOREIGN KEY (register_claim_id, organization_id, branch_id)
  REFERENCES register_claims(id, organization_id, branch_id) ON DELETE RESTRICT;

ALTER TABLE cash_movements
  ADD CONSTRAINT cash_movements_register_claim_fk
  FOREIGN KEY (register_claim_id, organization_id, branch_id)
  REFERENCES register_claims(id, organization_id, branch_id) ON DELETE RESTRICT;

ALTER TABLE sales
  ADD CONSTRAINT sales_register_claim_fk
  FOREIGN KEY (register_claim_id, organization_id, branch_id)
  REFERENCES register_claims(id, organization_id, branch_id) ON DELETE RESTRICT;

CREATE TABLE IF NOT EXISTS sale_receipt_aliases (
  id text PRIMARY KEY,
  organization_id text NOT NULL REFERENCES organizations(id) ON DELETE RESTRICT,
  branch_id text NOT NULL,
  sale_id text NOT NULL,
  register_claim_id text,
  alias_receipt_number text NOT NULL,
  canonical_receipt_number text NOT NULL,
  alias_kind text NOT NULL DEFAULT 'offline_printed' CHECK (
    alias_kind IN ('offline_printed', 'legacy')
  ),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (organization_id, branch_id, alias_receipt_number),
  UNIQUE (sale_id, alias_receipt_number),
  FOREIGN KEY (branch_id, organization_id)
    REFERENCES branches(id, organization_id) ON DELETE RESTRICT,
  FOREIGN KEY (sale_id, organization_id, branch_id)
    REFERENCES sales(id, organization_id, branch_id) ON DELETE RESTRICT,
  FOREIGN KEY (register_claim_id, organization_id, branch_id)
    REFERENCES register_claims(id, organization_id, branch_id) ON DELETE RESTRICT
);

CREATE INDEX IF NOT EXISTS sale_receipt_aliases_canonical_idx
  ON sale_receipt_aliases (organization_id, branch_id, canonical_receipt_number);

CREATE INDEX IF NOT EXISTS change_feed_authorized_pull_idx
  ON change_feed (organization_id, branch_id, sequence);

CREATE INDEX IF NOT EXISTS products_snapshot_page_idx
  ON products (organization_id, id)
  WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS product_prices_snapshot_page_idx
  ON product_prices (organization_id, branch_id, id);
