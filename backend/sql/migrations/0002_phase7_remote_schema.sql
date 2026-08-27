ALTER TABLE organizations
  ADD COLUMN IF NOT EXISTS version integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS deleted_at timestamptz;
ALTER TABLE branches
  ADD COLUMN IF NOT EXISTS allow_negative_stock boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS adjustment_approval_threshold_milli bigint,
  ADD COLUMN IF NOT EXISTS allow_multiple_open_shifts_per_user boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS allow_sales_without_open_shift boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS cash_discrepancy_approval_threshold_minor bigint,
  ADD COLUMN IF NOT EXISTS discount_approval_threshold_basis_points integer,
  ADD COLUMN IF NOT EXISTS version integer NOT NULL DEFAULT 0;
ALTER TABLE app_users ADD COLUMN IF NOT EXISTS version integer NOT NULL DEFAULT 0;
ALTER TABLE roles ADD COLUMN IF NOT EXISTS version integer NOT NULL DEFAULT 0;
ALTER TABLE permissions ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();
ALTER TABLE user_role_assignments
  ADD COLUMN IF NOT EXISTS version integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();
ALTER TABLE devices
  ADD COLUMN IF NOT EXISTS version integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

CREATE UNIQUE INDEX IF NOT EXISTS organizations_id_organization_uidx
  ON organizations (id);
CREATE UNIQUE INDEX IF NOT EXISTS branches_id_organization_uidx
  ON branches (id, organization_id);
CREATE UNIQUE INDEX IF NOT EXISTS app_users_id_organization_uidx
  ON app_users (id, organization_id);
CREATE UNIQUE INDEX IF NOT EXISTS roles_id_organization_uidx
  ON roles (id, organization_id);

DO $$
DECLARE
  version_target record;
BEGIN
  FOR version_target IN
    SELECT * FROM (VALUES
      ('organizations', 'organizations_version_check'),
      ('branches', 'branches_version_check'),
      ('app_users', 'app_users_version_check'),
      ('roles', 'roles_version_check'),
      ('user_role_assignments', 'user_role_assignments_version_check'),
      ('devices', 'devices_version_check')
    ) AS targets(table_name, constraint_name)
  LOOP
    IF NOT EXISTS (
      SELECT 1 FROM pg_constraint
      WHERE conname = version_target.constraint_name
    ) THEN
      EXECUTE format(
        'ALTER TABLE %I ADD CONSTRAINT %I CHECK (version >= 0)',
        version_target.table_name,
        version_target.constraint_name
      );
    END IF;
  END LOOP;
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'user_role_assignments_branch_organization_fk'
  ) THEN
    ALTER TABLE user_role_assignments
      ADD CONSTRAINT user_role_assignments_branch_organization_fk
      FOREIGN KEY (branch_id, organization_id)
      REFERENCES branches(id, organization_id) ON DELETE RESTRICT;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'user_role_assignments_user_organization_fk'
  ) THEN
    ALTER TABLE user_role_assignments
      ADD CONSTRAINT user_role_assignments_user_organization_fk
      FOREIGN KEY (user_id, organization_id)
      REFERENCES app_users(id, organization_id) ON DELETE CASCADE;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'user_role_assignments_role_organization_fk'
  ) THEN
    ALTER TABLE user_role_assignments
      ADD CONSTRAINT user_role_assignments_role_organization_fk
      FOREIGN KEY (role_id, organization_id)
      REFERENCES roles(id, organization_id) ON DELETE RESTRICT;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'devices_branch_organization_fk'
  ) THEN
    ALTER TABLE devices
      ADD CONSTRAINT devices_branch_organization_fk
      FOREIGN KEY (branch_id, organization_id)
      REFERENCES branches(id, organization_id) ON DELETE RESTRICT;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'devices_user_organization_fk'
  ) THEN
    ALTER TABLE devices
      ADD CONSTRAINT devices_user_organization_fk
      FOREIGN KEY (user_id, organization_id)
      REFERENCES app_users(id, organization_id) ON DELETE CASCADE;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'branches_adjustment_threshold_check'
  ) THEN
    ALTER TABLE branches ADD CONSTRAINT branches_adjustment_threshold_check
      CHECK (adjustment_approval_threshold_milli IS NULL OR adjustment_approval_threshold_milli >= 0);
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'branches_cash_discrepancy_threshold_check'
  ) THEN
    ALTER TABLE branches ADD CONSTRAINT branches_cash_discrepancy_threshold_check
      CHECK (cash_discrepancy_approval_threshold_minor IS NULL OR cash_discrepancy_approval_threshold_minor >= 0);
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'branches_discount_threshold_check'
  ) THEN
    ALTER TABLE branches ADD CONSTRAINT branches_discount_threshold_check
      CHECK (
        discount_approval_threshold_basis_points IS NULL OR
        discount_approval_threshold_basis_points BETWEEN 0 AND 10000
      );
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS categories (
  id text PRIMARY KEY,
  organization_id text NOT NULL REFERENCES organizations(id) ON DELETE RESTRICT,
  name text NOT NULL,
  normalized_name text NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  version integer NOT NULL DEFAULT 0 CHECK (version >= 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz,
  UNIQUE (organization_id, normalized_name),
  UNIQUE (id, organization_id)
);

CREATE TABLE IF NOT EXISTS units (
  id text PRIMARY KEY,
  organization_id text NOT NULL REFERENCES organizations(id) ON DELETE RESTRICT,
  code text NOT NULL,
  name text NOT NULL,
  abbreviation text NOT NULL,
  allows_fractional boolean NOT NULL DEFAULT false,
  is_active boolean NOT NULL DEFAULT true,
  version integer NOT NULL DEFAULT 0 CHECK (version >= 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz,
  UNIQUE (organization_id, code),
  UNIQUE (id, organization_id)
);

CREATE TABLE IF NOT EXISTS tax_categories (
  id text PRIMARY KEY,
  organization_id text NOT NULL REFERENCES organizations(id) ON DELETE RESTRICT,
  code text NOT NULL,
  name text NOT NULL,
  rate_basis_points integer NOT NULL CHECK (rate_basis_points BETWEEN 0 AND 10000),
  is_inclusive boolean NOT NULL DEFAULT true,
  is_active boolean NOT NULL DEFAULT true,
  version integer NOT NULL DEFAULT 0 CHECK (version >= 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz,
  UNIQUE (organization_id, code),
  UNIQUE (id, organization_id)
);

CREATE TABLE IF NOT EXISTS products (
  id text PRIMARY KEY,
  organization_id text NOT NULL REFERENCES organizations(id) ON DELETE RESTRICT,
  category_id text,
  unit_id text NOT NULL,
  tax_category_id text,
  sku text NOT NULL,
  normalized_sku text NOT NULL,
  name text NOT NULL,
  normalized_name text NOT NULL,
  description text,
  is_active boolean NOT NULL DEFAULT true,
  version integer NOT NULL DEFAULT 0 CHECK (version >= 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz,
  UNIQUE (organization_id, sku),
  UNIQUE (organization_id, normalized_sku),
  UNIQUE (id, organization_id),
  FOREIGN KEY (category_id, organization_id)
    REFERENCES categories(id, organization_id) ON DELETE RESTRICT,
  FOREIGN KEY (unit_id, organization_id)
    REFERENCES units(id, organization_id) ON DELETE RESTRICT,
  FOREIGN KEY (tax_category_id, organization_id)
    REFERENCES tax_categories(id, organization_id) ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS product_barcodes (
  id text PRIMARY KEY,
  organization_id text NOT NULL REFERENCES organizations(id) ON DELETE RESTRICT,
  product_id text NOT NULL,
  barcode text NOT NULL,
  normalized_barcode text NOT NULL,
  is_primary boolean NOT NULL DEFAULT false,
  version integer NOT NULL DEFAULT 0 CHECK (version >= 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz,
  UNIQUE (organization_id, barcode),
  UNIQUE (organization_id, normalized_barcode),
  FOREIGN KEY (product_id, organization_id)
    REFERENCES products(id, organization_id) ON DELETE CASCADE
);

CREATE UNIQUE INDEX IF NOT EXISTS product_barcodes_primary_uidx
  ON product_barcodes (product_id)
  WHERE is_primary = true AND deleted_at IS NULL;

CREATE TABLE IF NOT EXISTS product_prices (
  id text PRIMARY KEY,
  organization_id text NOT NULL REFERENCES organizations(id) ON DELETE RESTRICT,
  product_id text NOT NULL,
  branch_id text,
  branch_scope text NOT NULL,
  unit_price_minor bigint NOT NULL CHECK (unit_price_minor >= 0),
  effective_from timestamptz NOT NULL,
  effective_to timestamptz,
  created_by_user_id text NOT NULL,
  version integer NOT NULL DEFAULT 0 CHECK (version >= 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (product_id, branch_scope, effective_from),
  FOREIGN KEY (product_id, organization_id)
    REFERENCES products(id, organization_id) ON DELETE CASCADE,
  FOREIGN KEY (branch_id, organization_id)
    REFERENCES branches(id, organization_id) ON DELETE RESTRICT,
  FOREIGN KEY (created_by_user_id, organization_id)
    REFERENCES app_users(id, organization_id) ON DELETE RESTRICT,
  CHECK (
    (branch_id IS NULL AND branch_scope = '*') OR
    (branch_id IS NOT NULL AND branch_scope = branch_id)
  ),
  CHECK (effective_to IS NULL OR effective_to > effective_from)
);

CREATE TABLE IF NOT EXISTS product_images (
  id text PRIMARY KEY,
  organization_id text NOT NULL REFERENCES organizations(id) ON DELETE RESTRICT,
  product_id text NOT NULL,
  storage_path text,
  remote_url text,
  upload_status text NOT NULL DEFAULT 'pending'
    CHECK (upload_status IN ('pending', 'uploading', 'uploaded', 'failed')),
  sort_order integer NOT NULL DEFAULT 0 CHECK (sort_order >= 0),
  version integer NOT NULL DEFAULT 0 CHECK (version >= 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz,
  FOREIGN KEY (product_id, organization_id)
    REFERENCES products(id, organization_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS products_organization_updated_idx
  ON products (organization_id, updated_at);
CREATE INDEX IF NOT EXISTS products_name_search_idx
  ON products (organization_id, normalized_name);
CREATE INDEX IF NOT EXISTS products_sku_search_idx
  ON products (organization_id, normalized_sku);
CREATE INDEX IF NOT EXISTS product_barcodes_search_idx
  ON product_barcodes (organization_id, normalized_barcode);

CREATE TABLE IF NOT EXISTS stock_locations (
  id text PRIMARY KEY,
  organization_id text NOT NULL REFERENCES organizations(id) ON DELETE RESTRICT,
  branch_id text NOT NULL,
  code text NOT NULL,
  name text NOT NULL,
  location_type text NOT NULL DEFAULT 'warehouse'
    CHECK (location_type IN ('sales_floor', 'warehouse', 'returns', 'damaged')),
  is_default boolean NOT NULL DEFAULT false,
  is_active boolean NOT NULL DEFAULT true,
  version integer NOT NULL DEFAULT 0 CHECK (version >= 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz,
  UNIQUE (organization_id, branch_id, code),
  UNIQUE (id, organization_id, branch_id),
  FOREIGN KEY (branch_id, organization_id)
    REFERENCES branches(id, organization_id) ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS inventory_transactions (
  id text PRIMARY KEY,
  organization_id text NOT NULL REFERENCES organizations(id) ON DELETE RESTRICT,
  branch_id text NOT NULL,
  operation_id text NOT NULL,
  transaction_type text NOT NULL CHECK (
    transaction_type IN (
      'opening_balance', 'purchase_receipt', 'sale', 'sale_return',
      'adjustment_increase', 'adjustment_decrease', 'transfer_shipment',
      'transfer_receipt', 'stock_count_correction', 'reversal'
    )
  ),
  status text NOT NULL DEFAULT 'posted' CHECK (status IN ('posted', 'reversed')),
  reason_code text,
  notes text,
  reference_type text,
  reference_id text,
  reverses_transaction_id text REFERENCES inventory_transactions(id) ON DELETE RESTRICT,
  occurred_during_stock_count boolean NOT NULL DEFAULT false,
  created_by_user_id text NOT NULL,
  approved_by_user_id text,
  approved_at timestamptz,
  occurred_at timestamptz NOT NULL,
  version integer NOT NULL DEFAULT 0 CHECK (version >= 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (organization_id, operation_id),
  UNIQUE (id, organization_id, branch_id),
  FOREIGN KEY (branch_id, organization_id)
    REFERENCES branches(id, organization_id) ON DELETE RESTRICT,
  FOREIGN KEY (created_by_user_id, organization_id)
    REFERENCES app_users(id, organization_id) ON DELETE RESTRICT,
  FOREIGN KEY (approved_by_user_id, organization_id)
    REFERENCES app_users(id, organization_id) ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS inventory_balances (
  id text PRIMARY KEY,
  organization_id text NOT NULL REFERENCES organizations(id) ON DELETE RESTRICT,
  branch_id text NOT NULL,
  stock_location_id text NOT NULL,
  product_id text NOT NULL,
  on_hand_milli bigint NOT NULL DEFAULT 0,
  reserved_milli bigint NOT NULL DEFAULT 0 CHECK (reserved_milli >= 0),
  reorder_point_milli bigint NOT NULL DEFAULT 0 CHECK (reorder_point_milli >= 0),
  version integer NOT NULL DEFAULT 0 CHECK (version >= 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (organization_id, branch_id, stock_location_id, product_id),
  FOREIGN KEY (branch_id, organization_id)
    REFERENCES branches(id, organization_id) ON DELETE RESTRICT,
  FOREIGN KEY (stock_location_id, organization_id, branch_id)
    REFERENCES stock_locations(id, organization_id, branch_id) ON DELETE RESTRICT,
  FOREIGN KEY (product_id, organization_id)
    REFERENCES products(id, organization_id) ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS inventory_ledger_entries (
  id text PRIMARY KEY,
  organization_id text NOT NULL REFERENCES organizations(id) ON DELETE RESTRICT,
  branch_id text NOT NULL,
  transaction_id text NOT NULL,
  stock_location_id text NOT NULL,
  product_id text NOT NULL,
  quantity_delta_milli bigint NOT NULL CHECK (quantity_delta_milli <> 0),
  balance_after_milli bigint NOT NULL,
  occurred_at timestamptz NOT NULL,
  version integer NOT NULL DEFAULT 0 CHECK (version >= 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (transaction_id, stock_location_id, product_id),
  FOREIGN KEY (transaction_id, organization_id, branch_id)
    REFERENCES inventory_transactions(id, organization_id, branch_id) ON DELETE RESTRICT,
  FOREIGN KEY (stock_location_id, organization_id, branch_id)
    REFERENCES stock_locations(id, organization_id, branch_id) ON DELETE RESTRICT,
  FOREIGN KEY (product_id, organization_id)
    REFERENCES products(id, organization_id) ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS stock_counts (
  id text PRIMARY KEY,
  organization_id text NOT NULL REFERENCES organizations(id) ON DELETE RESTRICT,
  branch_id text NOT NULL,
  stock_location_id text NOT NULL,
  operation_id text NOT NULL,
  completion_operation_id text,
  count_type text NOT NULL CHECK (count_type IN ('full', 'cycle')),
  status text NOT NULL DEFAULT 'in_progress'
    CHECK (status IN ('in_progress', 'completed', 'cancelled')),
  notes text,
  started_by_user_id text NOT NULL,
  started_at timestamptz NOT NULL,
  completed_by_user_id text,
  completed_at timestamptz,
  version integer NOT NULL DEFAULT 0 CHECK (version >= 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (organization_id, operation_id),
  UNIQUE (organization_id, completion_operation_id),
  UNIQUE (id, organization_id, branch_id),
  UNIQUE (id, organization_id),
  FOREIGN KEY (branch_id, organization_id)
    REFERENCES branches(id, organization_id) ON DELETE RESTRICT,
  FOREIGN KEY (stock_location_id, organization_id, branch_id)
    REFERENCES stock_locations(id, organization_id, branch_id) ON DELETE RESTRICT,
  FOREIGN KEY (started_by_user_id, organization_id)
    REFERENCES app_users(id, organization_id) ON DELETE RESTRICT,
  FOREIGN KEY (completed_by_user_id, organization_id)
    REFERENCES app_users(id, organization_id) ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS stock_count_items (
  id text PRIMARY KEY,
  organization_id text NOT NULL REFERENCES organizations(id) ON DELETE RESTRICT,
  stock_count_id text NOT NULL,
  product_id text NOT NULL,
  expected_quantity_milli bigint NOT NULL,
  counted_quantity_milli bigint,
  variance_quantity_milli bigint,
  counted_by_user_id text,
  counted_at timestamptz,
  version integer NOT NULL DEFAULT 0 CHECK (version >= 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (stock_count_id, product_id),
  FOREIGN KEY (stock_count_id, organization_id)
    REFERENCES stock_counts(id, organization_id) ON DELETE RESTRICT,
  FOREIGN KEY (product_id, organization_id)
    REFERENCES products(id, organization_id) ON DELETE RESTRICT,
  FOREIGN KEY (counted_by_user_id, organization_id)
    REFERENCES app_users(id, organization_id) ON DELETE RESTRICT
);

CREATE INDEX IF NOT EXISTS inventory_transactions_history_idx
  ON inventory_transactions (organization_id, branch_id, occurred_at);
CREATE UNIQUE INDEX IF NOT EXISTS inventory_transactions_one_reversal_uidx
  ON inventory_transactions (organization_id, reverses_transaction_id)
  WHERE reverses_transaction_id IS NOT NULL AND status = 'posted';
CREATE INDEX IF NOT EXISTS inventory_ledger_product_history_idx
  ON inventory_ledger_entries (organization_id, branch_id, product_id, occurred_at);
CREATE INDEX IF NOT EXISTS inventory_balances_low_stock_idx
  ON inventory_balances (organization_id, branch_id, stock_location_id, on_hand_milli);
CREATE UNIQUE INDEX IF NOT EXISTS stock_counts_one_open_location_uidx
  ON stock_counts (organization_id, branch_id, stock_location_id)
  WHERE status = 'in_progress';

CREATE TABLE IF NOT EXISTS registers (
  id text PRIMARY KEY,
  organization_id text NOT NULL REFERENCES organizations(id) ON DELETE RESTRICT,
  branch_id text NOT NULL,
  code text NOT NULL,
  name text NOT NULL,
  assigned_device_id text,
  assigned_by_user_id text,
  assigned_at timestamptz,
  is_active boolean NOT NULL DEFAULT true,
  version integer NOT NULL DEFAULT 0 CHECK (version >= 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz,
  UNIQUE (organization_id, branch_id, code),
  UNIQUE (organization_id, branch_id, assigned_device_id),
  UNIQUE (id, organization_id, branch_id),
  FOREIGN KEY (branch_id, organization_id)
    REFERENCES branches(id, organization_id) ON DELETE RESTRICT,
  FOREIGN KEY (assigned_by_user_id, organization_id)
    REFERENCES app_users(id, organization_id) ON DELETE RESTRICT,
  FOREIGN KEY (organization_id, assigned_device_id)
    REFERENCES devices(organization_id, id) ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS shifts (
  id text PRIMARY KEY,
  organization_id text NOT NULL REFERENCES organizations(id) ON DELETE RESTRICT,
  branch_id text NOT NULL,
  register_id text NOT NULL,
  device_id text NOT NULL,
  operation_id text NOT NULL,
  close_operation_id text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'closed')),
  opening_cash_minor bigint NOT NULL CHECK (opening_cash_minor >= 0),
  expected_cash_minor bigint,
  counted_cash_minor bigint CHECK (counted_cash_minor IS NULL OR counted_cash_minor >= 0),
  discrepancy_minor bigint,
  opening_notes text,
  closing_notes text,
  opened_by_user_id text NOT NULL,
  opened_at timestamptz NOT NULL,
  closed_by_user_id text,
  closed_at timestamptz,
  approved_by_user_id text,
  approved_at timestamptz,
  approval_notes text,
  version integer NOT NULL DEFAULT 0 CHECK (version >= 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (organization_id, operation_id),
  UNIQUE (organization_id, close_operation_id),
  UNIQUE (id, organization_id, branch_id),
  FOREIGN KEY (branch_id, organization_id)
    REFERENCES branches(id, organization_id) ON DELETE RESTRICT,
  FOREIGN KEY (register_id, organization_id, branch_id)
    REFERENCES registers(id, organization_id, branch_id) ON DELETE RESTRICT,
  FOREIGN KEY (opened_by_user_id, organization_id)
    REFERENCES app_users(id, organization_id) ON DELETE RESTRICT,
  FOREIGN KEY (closed_by_user_id, organization_id)
    REFERENCES app_users(id, organization_id) ON DELETE RESTRICT,
  FOREIGN KEY (approved_by_user_id, organization_id)
    REFERENCES app_users(id, organization_id) ON DELETE RESTRICT,
  FOREIGN KEY (organization_id, device_id)
    REFERENCES devices(organization_id, id) ON DELETE RESTRICT,
  CHECK (
    (status = 'open' AND closed_at IS NULL AND closed_by_user_id IS NULL) OR
    (status = 'closed' AND closed_at IS NOT NULL AND closed_by_user_id IS NOT NULL)
  )
);

CREATE UNIQUE INDEX IF NOT EXISTS shifts_one_open_per_register_uidx
  ON shifts (organization_id, branch_id, register_id)
  WHERE status = 'open';

CREATE TABLE IF NOT EXISTS cash_movements (
  id text PRIMARY KEY,
  organization_id text NOT NULL REFERENCES organizations(id) ON DELETE RESTRICT,
  branch_id text NOT NULL,
  register_id text NOT NULL,
  shift_id text NOT NULL,
  operation_id text NOT NULL,
  movement_type text NOT NULL CHECK (movement_type IN ('cash_in', 'cash_out', 'payout', 'correction')),
  amount_minor bigint NOT NULL,
  reason text NOT NULL,
  created_by_user_id text NOT NULL,
  approved_by_user_id text,
  approved_at timestamptz,
  occurred_at timestamptz NOT NULL,
  version integer NOT NULL DEFAULT 0 CHECK (version >= 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (organization_id, operation_id),
  FOREIGN KEY (branch_id, organization_id)
    REFERENCES branches(id, organization_id) ON DELETE RESTRICT,
  FOREIGN KEY (register_id, organization_id, branch_id)
    REFERENCES registers(id, organization_id, branch_id) ON DELETE RESTRICT,
  FOREIGN KEY (shift_id, organization_id, branch_id)
    REFERENCES shifts(id, organization_id, branch_id) ON DELETE RESTRICT,
  FOREIGN KEY (created_by_user_id, organization_id)
    REFERENCES app_users(id, organization_id) ON DELETE RESTRICT,
  FOREIGN KEY (approved_by_user_id, organization_id)
    REFERENCES app_users(id, organization_id) ON DELETE RESTRICT,
  CHECK (
    (movement_type = 'cash_in' AND amount_minor > 0) OR
    (movement_type IN ('cash_out', 'payout') AND amount_minor < 0) OR
    (movement_type = 'correction' AND amount_minor <> 0)
  )
);

CREATE TABLE IF NOT EXISTS shift_counts (
  id text PRIMARY KEY,
  organization_id text NOT NULL REFERENCES organizations(id) ON DELETE RESTRICT,
  branch_id text NOT NULL,
  shift_id text NOT NULL,
  payment_method text NOT NULL CHECK (payment_method IN ('cash', 'card', 'e_wallet')),
  expected_amount_minor bigint NOT NULL,
  counted_amount_minor bigint NOT NULL CHECK (counted_amount_minor >= 0),
  discrepancy_minor bigint NOT NULL,
  counted_by_user_id text NOT NULL,
  counted_at timestamptz NOT NULL,
  version integer NOT NULL DEFAULT 0 CHECK (version >= 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (shift_id, payment_method),
  FOREIGN KEY (branch_id, organization_id)
    REFERENCES branches(id, organization_id) ON DELETE RESTRICT,
  FOREIGN KEY (shift_id, organization_id, branch_id)
    REFERENCES shifts(id, organization_id, branch_id) ON DELETE RESTRICT,
  FOREIGN KEY (counted_by_user_id, organization_id)
    REFERENCES app_users(id, organization_id) ON DELETE RESTRICT,
  CHECK (discrepancy_minor = counted_amount_minor - expected_amount_minor)
);

CREATE INDEX IF NOT EXISTS registers_branch_idx
  ON registers (organization_id, branch_id, is_active);
CREATE INDEX IF NOT EXISTS shifts_active_idx
  ON shifts (organization_id, branch_id, status, opened_by_user_id);
CREATE INDEX IF NOT EXISTS cash_movements_shift_idx
  ON cash_movements (organization_id, branch_id, shift_id, occurred_at);

CREATE TABLE IF NOT EXISTS sales (
  id text PRIMARY KEY,
  organization_id text NOT NULL REFERENCES organizations(id) ON DELETE RESTRICT,
  branch_id text NOT NULL,
  register_id text NOT NULL,
  shift_id text,
  inventory_transaction_id text,
  operation_id text NOT NULL,
  receipt_number text,
  status text NOT NULL DEFAULT 'draft' CHECK (
    status IN ('draft', 'completed', 'voided', 'partially_returned', 'returned', 'sync_rejected')
  ),
  cashier_user_id text NOT NULL,
  subtotal_minor bigint NOT NULL DEFAULT 0 CHECK (subtotal_minor >= 0),
  discount_minor bigint NOT NULL DEFAULT 0 CHECK (discount_minor >= 0),
  tax_minor bigint NOT NULL DEFAULT 0 CHECK (tax_minor >= 0),
  total_minor bigint NOT NULL DEFAULT 0 CHECK (total_minor >= 0),
  tendered_minor bigint NOT NULL DEFAULT 0 CHECK (tendered_minor >= 0),
  change_minor bigint NOT NULL DEFAULT 0 CHECK (change_minor >= 0),
  discount_approved_by_user_id text,
  discount_approved_at timestamptz,
  completed_at timestamptz,
  version integer NOT NULL DEFAULT 0 CHECK (version >= 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (organization_id, operation_id),
  UNIQUE (organization_id, branch_id, receipt_number),
  UNIQUE (id, organization_id, branch_id),
  FOREIGN KEY (branch_id, organization_id)
    REFERENCES branches(id, organization_id) ON DELETE RESTRICT,
  FOREIGN KEY (register_id, organization_id, branch_id)
    REFERENCES registers(id, organization_id, branch_id) ON DELETE RESTRICT,
  FOREIGN KEY (shift_id, organization_id, branch_id)
    REFERENCES shifts(id, organization_id, branch_id) ON DELETE RESTRICT,
  FOREIGN KEY (inventory_transaction_id, organization_id, branch_id)
    REFERENCES inventory_transactions(id, organization_id, branch_id) ON DELETE RESTRICT,
  FOREIGN KEY (cashier_user_id, organization_id)
    REFERENCES app_users(id, organization_id) ON DELETE RESTRICT,
  FOREIGN KEY (discount_approved_by_user_id, organization_id)
    REFERENCES app_users(id, organization_id) ON DELETE RESTRICT,
  CHECK (
    (status = 'draft' AND completed_at IS NULL) OR
    (status <> 'draft' AND completed_at IS NOT NULL)
  ),
  CHECK (discount_minor <= subtotal_minor)
);

CREATE TABLE IF NOT EXISTS sale_items (
  id text PRIMARY KEY,
  organization_id text NOT NULL REFERENCES organizations(id) ON DELETE RESTRICT,
  branch_id text NOT NULL,
  sale_id text NOT NULL,
  product_id text NOT NULL,
  stock_location_id text NOT NULL,
  line_number integer NOT NULL CHECK (line_number > 0),
  product_name_snapshot text NOT NULL,
  sku_snapshot text NOT NULL,
  barcode_snapshot text,
  unit_name_snapshot text NOT NULL,
  quantity_milli bigint NOT NULL CHECK (quantity_milli > 0),
  unit_price_minor_snapshot bigint NOT NULL CHECK (unit_price_minor_snapshot >= 0),
  unit_cost_minor_snapshot bigint NOT NULL DEFAULT 0 CHECK (unit_cost_minor_snapshot >= 0),
  tax_rate_basis_points_snapshot integer NOT NULL CHECK (tax_rate_basis_points_snapshot BETWEEN 0 AND 10000),
  tax_inclusive_snapshot boolean NOT NULL,
  gross_amount_minor bigint NOT NULL CHECK (gross_amount_minor >= 0),
  discount_amount_minor bigint NOT NULL CHECK (discount_amount_minor >= 0),
  net_amount_minor bigint NOT NULL CHECK (net_amount_minor >= 0),
  tax_amount_minor bigint NOT NULL CHECK (tax_amount_minor >= 0),
  total_amount_minor bigint NOT NULL CHECK (total_amount_minor >= 0),
  version integer NOT NULL DEFAULT 0 CHECK (version >= 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (sale_id, line_number),
  UNIQUE (id, sale_id),
  FOREIGN KEY (sale_id, organization_id, branch_id)
    REFERENCES sales(id, organization_id, branch_id) ON DELETE RESTRICT,
  FOREIGN KEY (product_id, organization_id)
    REFERENCES products(id, organization_id) ON DELETE RESTRICT,
  FOREIGN KEY (stock_location_id, organization_id, branch_id)
    REFERENCES stock_locations(id, organization_id, branch_id) ON DELETE RESTRICT,
  CHECK (discount_amount_minor <= gross_amount_minor)
);

CREATE TABLE IF NOT EXISTS payments (
  id text PRIMARY KEY,
  organization_id text NOT NULL REFERENCES organizations(id) ON DELETE RESTRICT,
  branch_id text NOT NULL,
  sale_id text NOT NULL,
  shift_id text,
  payment_method text NOT NULL CHECK (payment_method IN ('cash', 'card', 'e_wallet')),
  tendered_amount_minor bigint NOT NULL CHECK (tendered_amount_minor > 0),
  applied_amount_minor bigint NOT NULL CHECK (applied_amount_minor > 0),
  change_amount_minor bigint NOT NULL DEFAULT 0 CHECK (change_amount_minor >= 0),
  reference text,
  version integer NOT NULL DEFAULT 0 CHECK (version >= 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (sale_id, payment_method),
  FOREIGN KEY (sale_id, organization_id, branch_id)
    REFERENCES sales(id, organization_id, branch_id) ON DELETE RESTRICT,
  FOREIGN KEY (shift_id, organization_id, branch_id)
    REFERENCES shifts(id, organization_id, branch_id) ON DELETE RESTRICT,
  CHECK (tendered_amount_minor = applied_amount_minor + change_amount_minor),
  CHECK (payment_method = 'cash' OR change_amount_minor = 0)
);

CREATE TABLE IF NOT EXISTS sale_discounts (
  id text PRIMARY KEY,
  organization_id text NOT NULL REFERENCES organizations(id) ON DELETE RESTRICT,
  branch_id text NOT NULL,
  sale_id text NOT NULL,
  sale_item_id text,
  discount_scope text NOT NULL CHECK (discount_scope IN ('item', 'sale')),
  discount_type text NOT NULL DEFAULT 'fixed_amount' CHECK (discount_type = 'fixed_amount'),
  amount_minor bigint NOT NULL CHECK (amount_minor > 0),
  reason text NOT NULL,
  approved_by_user_id text,
  approved_at timestamptz,
  version integer NOT NULL DEFAULT 0 CHECK (version >= 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (sale_id, organization_id, branch_id)
    REFERENCES sales(id, organization_id, branch_id) ON DELETE RESTRICT,
  FOREIGN KEY (sale_item_id, sale_id)
    REFERENCES sale_items(id, sale_id) ON DELETE RESTRICT,
  FOREIGN KEY (approved_by_user_id, organization_id)
    REFERENCES app_users(id, organization_id) ON DELETE RESTRICT,
  CHECK (
    (discount_scope = 'item' AND sale_item_id IS NOT NULL) OR
    (discount_scope = 'sale' AND sale_item_id IS NULL)
  )
);

CREATE TABLE IF NOT EXISTS receipt_sequences (
  id text PRIMARY KEY,
  organization_id text NOT NULL REFERENCES organizations(id) ON DELETE RESTRICT,
  branch_id text NOT NULL,
  register_id text NOT NULL,
  next_sequence bigint NOT NULL DEFAULT 1 CHECK (next_sequence > 0),
  last_issued_at timestamptz,
  version integer NOT NULL DEFAULT 0 CHECK (version >= 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (organization_id, branch_id, register_id),
  FOREIGN KEY (branch_id, organization_id)
    REFERENCES branches(id, organization_id) ON DELETE RESTRICT,
  FOREIGN KEY (register_id, organization_id, branch_id)
    REFERENCES registers(id, organization_id, branch_id) ON DELETE RESTRICT
);

CREATE INDEX IF NOT EXISTS sales_history_idx
  ON sales (organization_id, branch_id, completed_at);
CREATE INDEX IF NOT EXISTS payments_shift_idx
  ON payments (organization_id, branch_id, shift_id, created_at);

CREATE TABLE IF NOT EXISTS processed_operations (
  organization_id text NOT NULL REFERENCES organizations(id) ON DELETE RESTRICT,
  operation_id text NOT NULL,
  branch_id text,
  command_type text NOT NULL,
  aggregate_type text NOT NULL,
  aggregate_id text NOT NULL,
  actor_user_id text NOT NULL,
  firebase_uid text NOT NULL,
  result_json jsonb NOT NULL,
  processed_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (organization_id, operation_id),
  FOREIGN KEY (branch_id, organization_id)
    REFERENCES branches(id, organization_id) ON DELETE RESTRICT,
  FOREIGN KEY (actor_user_id, organization_id)
    REFERENCES app_users(id, organization_id) ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS audit_logs (
  id text PRIMARY KEY,
  organization_id text NOT NULL REFERENCES organizations(id) ON DELETE RESTRICT,
  branch_id text,
  actor_user_id text NOT NULL,
  firebase_uid text NOT NULL,
  operation_id text NOT NULL,
  action text NOT NULL,
  entity_type text NOT NULL,
  entity_id text NOT NULL,
  metadata_json jsonb NOT NULL DEFAULT '{}'::jsonb,
  occurred_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (branch_id, organization_id)
    REFERENCES branches(id, organization_id) ON DELETE RESTRICT,
  FOREIGN KEY (actor_user_id, organization_id)
    REFERENCES app_users(id, organization_id) ON DELETE RESTRICT,
  UNIQUE (organization_id, operation_id, action, entity_type, entity_id)
);

CREATE TABLE IF NOT EXISTS change_feed (
  sequence bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  organization_id text NOT NULL REFERENCES organizations(id) ON DELETE RESTRICT,
  branch_id text,
  aggregate_type text NOT NULL,
  aggregate_id text NOT NULL,
  operation_id text NOT NULL,
  change_type text NOT NULL CHECK (change_type IN ('upsert', 'delete')),
  version integer NOT NULL CHECK (version >= 0),
  payload_json jsonb NOT NULL,
  occurred_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (branch_id, organization_id)
    REFERENCES branches(id, organization_id) ON DELETE RESTRICT
);

CREATE INDEX IF NOT EXISTS processed_operations_aggregate_idx
  ON processed_operations (aggregate_type, aggregate_id);
CREATE INDEX IF NOT EXISTS change_feed_scope_sequence_idx
  ON change_feed (organization_id, branch_id, sequence);
CREATE INDEX IF NOT EXISTS audit_logs_scope_occurred_idx
  ON audit_logs (organization_id, branch_id, occurred_at);
CREATE INDEX IF NOT EXISTS branches_organization_updated_idx
  ON branches (organization_id, updated_at);
