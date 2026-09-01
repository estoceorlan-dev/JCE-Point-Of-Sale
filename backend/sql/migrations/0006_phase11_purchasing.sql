BEGIN;

INSERT INTO permissions (code, name, description, created_at)
VALUES
  ('purchases.approve', 'Approve purchase orders',
   'Approve submitted purchase orders.', now()),
  ('purchases.receive', 'Receive purchase orders',
   'Post branch goods receipts against approved purchase orders.', now()),
  ('suppliers.manage', 'Manage suppliers',
   'Create, maintain, and archive supplier records.', now())
ON CONFLICT (code) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description;

ALTER TABLE inventory_balances
  ADD COLUMN IF NOT EXISTS weighted_average_cost_minor bigint NOT NULL DEFAULT 0;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'inventory_balances_weighted_average_cost_check'
  ) THEN
    ALTER TABLE inventory_balances
      ADD CONSTRAINT inventory_balances_weighted_average_cost_check
      CHECK (weighted_average_cost_minor >= 0);
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS suppliers (
  id text PRIMARY KEY,
  organization_id text NOT NULL REFERENCES organizations(id) ON DELETE RESTRICT,
  code text NOT NULL,
  normalized_code text NOT NULL,
  name text NOT NULL,
  normalized_name text NOT NULL,
  tax_identifier text,
  payment_terms_days integer NOT NULL DEFAULT 0 CHECK (payment_terms_days >= 0),
  is_active boolean NOT NULL DEFAULT true,
  version integer NOT NULL DEFAULT 0 CHECK (version >= 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz,
  UNIQUE (organization_id, code),
  UNIQUE (organization_id, normalized_code),
  UNIQUE (id, organization_id)
);

CREATE TABLE IF NOT EXISTS supplier_contacts (
  id text PRIMARY KEY,
  organization_id text NOT NULL REFERENCES organizations(id) ON DELETE RESTRICT,
  supplier_id text NOT NULL,
  name text NOT NULL,
  role text,
  email text,
  phone text,
  is_primary boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (supplier_id, organization_id)
    REFERENCES suppliers(id, organization_id) ON DELETE RESTRICT,
  CHECK (email IS NOT NULL OR phone IS NOT NULL)
);

CREATE TABLE IF NOT EXISTS supplier_products (
  id text PRIMARY KEY,
  organization_id text NOT NULL REFERENCES organizations(id) ON DELETE RESTRICT,
  supplier_id text NOT NULL,
  product_id text NOT NULL,
  supplier_sku text,
  default_unit_cost_minor bigint NOT NULL DEFAULT 0
    CHECK (default_unit_cost_minor >= 0),
  minimum_order_quantity_milli bigint NOT NULL DEFAULT 1000
    CHECK (minimum_order_quantity_milli > 0),
  lead_time_days integer CHECK (lead_time_days IS NULL OR lead_time_days >= 0),
  is_preferred boolean NOT NULL DEFAULT false,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (supplier_id, product_id),
  FOREIGN KEY (supplier_id, organization_id)
    REFERENCES suppliers(id, organization_id) ON DELETE RESTRICT,
  FOREIGN KEY (product_id, organization_id)
    REFERENCES products(id, organization_id) ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS purchase_orders (
  id text PRIMARY KEY,
  organization_id text NOT NULL REFERENCES organizations(id) ON DELETE RESTRICT,
  branch_id text NOT NULL,
  supplier_id text NOT NULL,
  order_number text NOT NULL,
  status text NOT NULL CHECK (
    status IN ('draft', 'submitted', 'approved', 'partially_received',
               'received', 'cancelled')
  ),
  notes text,
  expected_delivery_at timestamptz,
  created_by_user_id text NOT NULL,
  approved_by_user_id text,
  cancellation_reason text,
  submitted_at timestamptz,
  approved_at timestamptz,
  cancelled_at timestamptz,
  version integer NOT NULL DEFAULT 0 CHECK (version >= 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (organization_id, branch_id, order_number),
  UNIQUE (id, organization_id, branch_id),
  FOREIGN KEY (branch_id, organization_id)
    REFERENCES branches(id, organization_id) ON DELETE RESTRICT,
  FOREIGN KEY (supplier_id, organization_id)
    REFERENCES suppliers(id, organization_id) ON DELETE RESTRICT,
  FOREIGN KEY (created_by_user_id, organization_id)
    REFERENCES app_users(id, organization_id) ON DELETE RESTRICT,
  FOREIGN KEY (approved_by_user_id, organization_id)
    REFERENCES app_users(id, organization_id) ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS purchase_order_items (
  id text PRIMARY KEY,
  organization_id text NOT NULL REFERENCES organizations(id) ON DELETE RESTRICT,
  branch_id text NOT NULL,
  purchase_order_id text NOT NULL,
  product_id text NOT NULL,
  ordered_quantity_milli bigint NOT NULL CHECK (ordered_quantity_milli > 0),
  received_quantity_milli bigint NOT NULL DEFAULT 0
    CHECK (received_quantity_milli >= 0),
  cancelled_quantity_milli bigint NOT NULL DEFAULT 0
    CHECK (cancelled_quantity_milli >= 0),
  unit_cost_minor bigint NOT NULL DEFAULT 0 CHECK (unit_cost_minor >= 0),
  estimated_landed_cost_minor bigint NOT NULL DEFAULT 0
    CHECK (estimated_landed_cost_minor >= 0),
  version integer NOT NULL DEFAULT 0 CHECK (version >= 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (purchase_order_id, product_id),
  FOREIGN KEY (purchase_order_id, organization_id, branch_id)
    REFERENCES purchase_orders(id, organization_id, branch_id) ON DELETE RESTRICT,
  FOREIGN KEY (product_id, organization_id)
    REFERENCES products(id, organization_id) ON DELETE RESTRICT,
  CHECK (
    received_quantity_milli + cancelled_quantity_milli <= ordered_quantity_milli
  )
);

CREATE TABLE IF NOT EXISTS goods_receipts (
  id text PRIMARY KEY,
  organization_id text NOT NULL REFERENCES organizations(id) ON DELETE RESTRICT,
  branch_id text NOT NULL,
  purchase_order_id text NOT NULL,
  supplier_id text NOT NULL,
  stock_location_id text NOT NULL,
  receipt_number text NOT NULL,
  operation_id text NOT NULL,
  supplier_document_number text,
  notes text,
  received_by_user_id text NOT NULL,
  received_at timestamptz NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (organization_id, operation_id),
  UNIQUE (organization_id, branch_id, receipt_number),
  UNIQUE (id, organization_id, branch_id),
  FOREIGN KEY (purchase_order_id, organization_id, branch_id)
    REFERENCES purchase_orders(id, organization_id, branch_id) ON DELETE RESTRICT,
  FOREIGN KEY (supplier_id, organization_id)
    REFERENCES suppliers(id, organization_id) ON DELETE RESTRICT,
  FOREIGN KEY (stock_location_id, organization_id, branch_id)
    REFERENCES stock_locations(id, organization_id, branch_id) ON DELETE RESTRICT,
  FOREIGN KEY (received_by_user_id, organization_id)
    REFERENCES app_users(id, organization_id) ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS goods_receipt_items (
  id text PRIMARY KEY,
  organization_id text NOT NULL REFERENCES organizations(id) ON DELETE RESTRICT,
  branch_id text NOT NULL,
  goods_receipt_id text NOT NULL,
  purchase_order_item_id text NOT NULL REFERENCES purchase_order_items(id) ON DELETE RESTRICT,
  product_id text NOT NULL,
  inventory_transaction_id text NOT NULL,
  received_quantity_milli bigint NOT NULL CHECK (received_quantity_milli > 0),
  unit_cost_minor bigint NOT NULL CHECK (unit_cost_minor >= 0),
  freight_cost_minor bigint NOT NULL DEFAULT 0 CHECK (freight_cost_minor >= 0),
  duty_cost_minor bigint NOT NULL DEFAULT 0 CHECK (duty_cost_minor >= 0),
  other_landed_cost_minor bigint NOT NULL DEFAULT 0
    CHECK (other_landed_cost_minor >= 0),
  landed_unit_cost_minor bigint NOT NULL CHECK (landed_unit_cost_minor >= 0),
  weighted_average_cost_minor_after bigint NOT NULL
    CHECK (weighted_average_cost_minor_after >= 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (goods_receipt_id, purchase_order_item_id),
  FOREIGN KEY (goods_receipt_id, organization_id, branch_id)
    REFERENCES goods_receipts(id, organization_id, branch_id) ON DELETE RESTRICT,
  FOREIGN KEY (product_id, organization_id)
    REFERENCES products(id, organization_id) ON DELETE RESTRICT,
  FOREIGN KEY (inventory_transaction_id, organization_id, branch_id)
    REFERENCES inventory_transactions(id, organization_id, branch_id)
    ON DELETE RESTRICT
);

CREATE INDEX IF NOT EXISTS suppliers_search_idx
  ON suppliers (organization_id, normalized_name, is_active);
CREATE INDEX IF NOT EXISTS purchase_orders_branch_status_idx
  ON purchase_orders (organization_id, branch_id, status, updated_at);
CREATE INDEX IF NOT EXISTS goods_receipts_history_idx
  ON goods_receipts (organization_id, branch_id, received_at);

COMMIT;
