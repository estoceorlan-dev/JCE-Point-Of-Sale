BEGIN;

ALTER TABLE branches
  ADD COLUMN IF NOT EXISTS transfer_approval_threshold_milli bigint;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'branches_transfer_approval_threshold_check'
  ) THEN
    ALTER TABLE branches ADD CONSTRAINT branches_transfer_approval_threshold_check
      CHECK (
        transfer_approval_threshold_milli IS NULL OR
        transfer_approval_threshold_milli >= 0
      );
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS stock_transfers (
  id text PRIMARY KEY,
  organization_id text NOT NULL REFERENCES organizations(id) ON DELETE RESTRICT,
  source_branch_id text NOT NULL,
  destination_branch_id text NOT NULL,
  transfer_number text NOT NULL,
  status text NOT NULL CHECK (
    status IN ('draft', 'submitted', 'approved', 'rejected',
               'shipped', 'received', 'cancelled')
  ),
  approval_required boolean NOT NULL DEFAULT false,
  notes text,
  created_by_user_id text NOT NULL,
  approved_by_user_id text,
  rejection_reason text,
  cancellation_reason text,
  submitted_at timestamptz,
  approved_at timestamptz,
  shipped_at timestamptz,
  received_at timestamptz,
  cancelled_at timestamptz,
  version integer NOT NULL DEFAULT 0 CHECK (version >= 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (organization_id, transfer_number),
  UNIQUE (id, organization_id),
  FOREIGN KEY (source_branch_id, organization_id)
    REFERENCES branches(id, organization_id) ON DELETE RESTRICT,
  FOREIGN KEY (destination_branch_id, organization_id)
    REFERENCES branches(id, organization_id) ON DELETE RESTRICT,
  FOREIGN KEY (created_by_user_id, organization_id)
    REFERENCES app_users(id, organization_id) ON DELETE RESTRICT,
  FOREIGN KEY (approved_by_user_id, organization_id)
    REFERENCES app_users(id, organization_id) ON DELETE RESTRICT,
  CHECK (source_branch_id <> destination_branch_id)
);

CREATE TABLE IF NOT EXISTS stock_transfer_items (
  id text PRIMARY KEY,
  organization_id text NOT NULL REFERENCES organizations(id) ON DELETE RESTRICT,
  transfer_id text NOT NULL,
  product_id text NOT NULL,
  source_stock_location_id text NOT NULL REFERENCES stock_locations(id) ON DELETE RESTRICT,
  destination_stock_location_id text NOT NULL REFERENCES stock_locations(id) ON DELETE RESTRICT,
  damaged_stock_location_id text REFERENCES stock_locations(id) ON DELETE RESTRICT,
  requested_quantity_milli bigint NOT NULL CHECK (requested_quantity_milli > 0),
  shipped_quantity_milli bigint NOT NULL DEFAULT 0 CHECK (shipped_quantity_milli >= 0),
  received_quantity_milli bigint NOT NULL DEFAULT 0 CHECK (received_quantity_milli >= 0),
  damaged_quantity_milli bigint NOT NULL DEFAULT 0 CHECK (damaged_quantity_milli >= 0),
  discrepancy_quantity_milli bigint NOT NULL DEFAULT 0 CHECK (discrepancy_quantity_milli >= 0),
  version integer NOT NULL DEFAULT 0 CHECK (version >= 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (transfer_id, source_stock_location_id, product_id),
  FOREIGN KEY (transfer_id, organization_id)
    REFERENCES stock_transfers(id, organization_id) ON DELETE RESTRICT,
  FOREIGN KEY (product_id, organization_id)
    REFERENCES products(id, organization_id) ON DELETE RESTRICT,
  CHECK (
    received_quantity_milli + damaged_quantity_milli <= shipped_quantity_milli
  )
);

CREATE TABLE IF NOT EXISTS transfer_events (
  id text PRIMARY KEY,
  organization_id text NOT NULL REFERENCES organizations(id) ON DELETE RESTRICT,
  transfer_id text NOT NULL,
  operation_id text NOT NULL,
  event_type text NOT NULL,
  from_status text,
  to_status text NOT NULL,
  actor_user_id text NOT NULL,
  reason text,
  metadata_json jsonb NOT NULL DEFAULT '{}'::jsonb,
  occurred_at timestamptz NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (organization_id, operation_id),
  FOREIGN KEY (transfer_id, organization_id)
    REFERENCES stock_transfers(id, organization_id) ON DELETE RESTRICT,
  FOREIGN KEY (actor_user_id, organization_id)
    REFERENCES app_users(id, organization_id) ON DELETE RESTRICT
);

CREATE INDEX IF NOT EXISTS stock_transfers_source_status_idx
  ON stock_transfers (organization_id, source_branch_id, status, updated_at);
CREATE INDEX IF NOT EXISTS stock_transfers_destination_status_idx
  ON stock_transfers (organization_id, destination_branch_id, status, updated_at);
CREATE INDEX IF NOT EXISTS transfer_events_history_idx
  ON transfer_events (organization_id, transfer_id, occurred_at);

COMMIT;
