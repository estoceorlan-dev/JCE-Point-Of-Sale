BEGIN;

ALTER TABLE branches
  ADD COLUMN IF NOT EXISTS return_approval_threshold_minor bigint,
  ADD COLUMN IF NOT EXISTS void_window_minutes integer NOT NULL DEFAULT 15;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'branches_return_approval_threshold_check'
  ) THEN
    ALTER TABLE branches ADD CONSTRAINT branches_return_approval_threshold_check
      CHECK (
        return_approval_threshold_minor IS NULL OR
        return_approval_threshold_minor >= 0
      );
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'branches_void_window_check'
  ) THEN
    ALTER TABLE branches ADD CONSTRAINT branches_void_window_check
      CHECK (void_window_minutes >= 0);
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS approval_requests (
  id text PRIMARY KEY,
  organization_id text NOT NULL REFERENCES organizations(id) ON DELETE RESTRICT,
  branch_id text NOT NULL,
  operation_id text NOT NULL,
  request_type text NOT NULL CHECK (request_type IN ('sale_return', 'sale_void')),
  entity_type text NOT NULL,
  entity_id text NOT NULL,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'approved', 'rejected', 'cancelled')),
  requested_by_user_id text NOT NULL,
  reason text NOT NULL,
  threshold_minor bigint CHECK (threshold_minor IS NULL OR threshold_minor >= 0),
  actual_amount_minor bigint NOT NULL CHECK (actual_amount_minor >= 0),
  requested_at timestamptz NOT NULL,
  resolved_at timestamptz,
  version integer NOT NULL DEFAULT 0 CHECK (version >= 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (organization_id, operation_id),
  UNIQUE (id, organization_id, branch_id),
  FOREIGN KEY (branch_id, organization_id)
    REFERENCES branches(id, organization_id) ON DELETE RESTRICT,
  FOREIGN KEY (requested_by_user_id, organization_id)
    REFERENCES app_users(id, organization_id) ON DELETE RESTRICT,
  CHECK (
    (status = 'pending' AND resolved_at IS NULL) OR
    (status <> 'pending' AND resolved_at IS NOT NULL)
  )
);

CREATE TABLE IF NOT EXISTS approval_decisions (
  id text PRIMARY KEY,
  organization_id text NOT NULL REFERENCES organizations(id) ON DELETE RESTRICT,
  branch_id text NOT NULL,
  approval_request_id text NOT NULL,
  decision text NOT NULL CHECK (decision IN ('approved', 'rejected')),
  decided_by_user_id text NOT NULL,
  notes text,
  decided_at timestamptz NOT NULL,
  version integer NOT NULL DEFAULT 0 CHECK (version >= 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (approval_request_id),
  FOREIGN KEY (branch_id, organization_id)
    REFERENCES branches(id, organization_id) ON DELETE RESTRICT,
  FOREIGN KEY (approval_request_id, organization_id, branch_id)
    REFERENCES approval_requests(id, organization_id, branch_id) ON DELETE RESTRICT,
  FOREIGN KEY (decided_by_user_id, organization_id)
    REFERENCES app_users(id, organization_id) ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS sale_returns (
  id text PRIMARY KEY,
  organization_id text NOT NULL REFERENCES organizations(id) ON DELETE RESTRICT,
  branch_id text NOT NULL,
  sale_id text NOT NULL,
  operation_id text NOT NULL,
  return_number text NOT NULL,
  correction_type text NOT NULL CHECK (correction_type IN ('return', 'void')),
  status text NOT NULL DEFAULT 'completed'
    CHECK (status IN ('completed', 'sync_rejected')),
  reason_code text NOT NULL,
  notes text,
  inventory_transaction_id text,
  approval_request_id text,
  subtotal_minor bigint NOT NULL CHECK (subtotal_minor >= 0),
  discount_minor bigint NOT NULL CHECK (discount_minor >= 0),
  tax_minor bigint NOT NULL CHECK (tax_minor >= 0),
  total_minor bigint NOT NULL CHECK (total_minor > 0),
  created_by_user_id text NOT NULL,
  approved_by_user_id text,
  approved_at timestamptz,
  completed_at timestamptz NOT NULL,
  version integer NOT NULL DEFAULT 0 CHECK (version >= 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (organization_id, operation_id),
  UNIQUE (organization_id, branch_id, return_number),
  UNIQUE (id, organization_id, branch_id),
  FOREIGN KEY (branch_id, organization_id)
    REFERENCES branches(id, organization_id) ON DELETE RESTRICT,
  FOREIGN KEY (sale_id, organization_id, branch_id)
    REFERENCES sales(id, organization_id, branch_id) ON DELETE RESTRICT,
  FOREIGN KEY (inventory_transaction_id, organization_id, branch_id)
    REFERENCES inventory_transactions(id, organization_id, branch_id) ON DELETE RESTRICT,
  FOREIGN KEY (approval_request_id, organization_id, branch_id)
    REFERENCES approval_requests(id, organization_id, branch_id) ON DELETE RESTRICT,
  FOREIGN KEY (created_by_user_id, organization_id)
    REFERENCES app_users(id, organization_id) ON DELETE RESTRICT,
  FOREIGN KEY (approved_by_user_id, organization_id)
    REFERENCES app_users(id, organization_id) ON DELETE RESTRICT,
  CHECK (discount_minor <= subtotal_minor),
  CHECK (
    (approval_request_id IS NULL AND approved_by_user_id IS NULL AND approved_at IS NULL) OR
    (approval_request_id IS NOT NULL AND approved_by_user_id IS NOT NULL AND approved_at IS NOT NULL)
  )
);

CREATE TABLE IF NOT EXISTS sale_return_items (
  id text PRIMARY KEY,
  organization_id text NOT NULL REFERENCES organizations(id) ON DELETE RESTRICT,
  branch_id text NOT NULL,
  sale_return_id text NOT NULL,
  sale_item_id text NOT NULL REFERENCES sale_items(id) ON DELETE RESTRICT,
  product_id text NOT NULL,
  disposition text NOT NULL CHECK (disposition IN ('restock', 'damaged', 'non_restock')),
  destination_stock_location_id text,
  quantity_milli bigint NOT NULL CHECK (quantity_milli > 0),
  subtotal_minor bigint NOT NULL CHECK (subtotal_minor >= 0),
  discount_minor bigint NOT NULL CHECK (discount_minor >= 0),
  tax_minor bigint NOT NULL CHECK (tax_minor >= 0),
  total_minor bigint NOT NULL CHECK (total_minor >= 0),
  version integer NOT NULL DEFAULT 0 CHECK (version >= 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (sale_return_id, sale_item_id),
  FOREIGN KEY (branch_id, organization_id)
    REFERENCES branches(id, organization_id) ON DELETE RESTRICT,
  FOREIGN KEY (sale_return_id, organization_id, branch_id)
    REFERENCES sale_returns(id, organization_id, branch_id) ON DELETE RESTRICT,
  FOREIGN KEY (product_id, organization_id)
    REFERENCES products(id, organization_id) ON DELETE RESTRICT,
  FOREIGN KEY (destination_stock_location_id, organization_id, branch_id)
    REFERENCES stock_locations(id, organization_id, branch_id) ON DELETE RESTRICT,
  CHECK (discount_minor <= subtotal_minor),
  CHECK (
    (disposition = 'non_restock' AND destination_stock_location_id IS NULL) OR
    (disposition <> 'non_restock' AND destination_stock_location_id IS NOT NULL)
  )
);

CREATE TABLE IF NOT EXISTS refund_payments (
  id text PRIMARY KEY,
  organization_id text NOT NULL REFERENCES organizations(id) ON DELETE RESTRICT,
  branch_id text NOT NULL,
  sale_return_id text NOT NULL,
  shift_id text,
  cash_movement_id text REFERENCES cash_movements(id) ON DELETE RESTRICT,
  refund_method text NOT NULL CHECK (
    refund_method IN ('cash', 'card', 'e_wallet', 'store_credit')
  ),
  amount_minor bigint NOT NULL CHECK (amount_minor > 0),
  reference text,
  version integer NOT NULL DEFAULT 0 CHECK (version >= 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (sale_return_id, refund_method),
  FOREIGN KEY (branch_id, organization_id)
    REFERENCES branches(id, organization_id) ON DELETE RESTRICT,
  FOREIGN KEY (sale_return_id, organization_id, branch_id)
    REFERENCES sale_returns(id, organization_id, branch_id) ON DELETE RESTRICT,
  FOREIGN KEY (shift_id, organization_id, branch_id)
    REFERENCES shifts(id, organization_id, branch_id) ON DELETE RESTRICT,
  CHECK (
    (refund_method = 'cash' AND shift_id IS NOT NULL AND cash_movement_id IS NOT NULL) OR
    (refund_method <> 'cash' AND cash_movement_id IS NULL)
  )
);

CREATE INDEX IF NOT EXISTS approval_requests_status_idx
  ON approval_requests (organization_id, branch_id, status, requested_at);
CREATE INDEX IF NOT EXISTS sale_returns_history_idx
  ON sale_returns (organization_id, branch_id, completed_at);

INSERT INTO permissions (code, name, description, updated_at)
VALUES
  (
    'sales.returns.process',
    'Process sale returns',
    'Create auditable sale returns and voids.',
    now()
  ),
  (
    'sales.corrections.approve',
    'Approve sale corrections',
    'Approve returns above branch limits and voids outside the cashier window.',
    now()
  )
ON CONFLICT (code) DO UPDATE
SET name = EXCLUDED.name,
    description = EXCLUDED.description,
    updated_at = now();

INSERT INTO role_permissions (role_id, permission_code, granted_at)
SELECT role.id, permission.code, now()
FROM roles AS role
CROSS JOIN (
  VALUES
    ('sales.returns.process'),
    ('sales.corrections.approve')
) AS permission(code)
WHERE role.code IN ('owner', 'admin', 'manager')
  AND role.is_active = true
  AND role.deleted_at IS NULL
ON CONFLICT (role_id, permission_code) DO NOTHING;

INSERT INTO role_permissions (role_id, permission_code, granted_at)
SELECT role.id, 'sales.returns.process', now()
FROM roles AS role
WHERE role.code = 'cashier'
  AND role.is_active = true
  AND role.deleted_at IS NULL
ON CONFLICT (role_id, permission_code) DO NOTHING;

COMMIT;
