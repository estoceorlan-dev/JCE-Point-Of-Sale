BEGIN;

INSERT INTO permissions (code, name, description, created_at)
VALUES
  ('customers.view', 'View customers',
   'Search customer records and view branch purchase history.', now()),
  ('customers.manage', 'Manage customers',
   'Create, update, archive, restore, merge, and annotate customers.', now()),
  ('customers.anonymize', 'Anonymize customers',
   'Permanently remove customer personal data while preserving audit history.', now()),
  ('loyalty.manage', 'Manage loyalty',
   'Post auditable customer loyalty point adjustments.', now())
ON CONFLICT (code) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  updated_at = now();

CREATE TABLE IF NOT EXISTS customers (
  id text PRIMARY KEY,
  organization_id text NOT NULL REFERENCES organizations(id) ON DELETE RESTRICT,
  customer_number text NOT NULL,
  display_name text NOT NULL,
  normalized_name text NOT NULL,
  email text,
  normalized_email text,
  phone text,
  normalized_phone text,
  birth_date timestamptz,
  marketing_consent boolean NOT NULL DEFAULT false,
  status text NOT NULL DEFAULT 'active' CHECK (
    status IN ('active', 'archived', 'anonymized', 'merged')
  ),
  merged_into_customer_id text,
  archived_at timestamptz,
  anonymized_at timestamptz,
  version integer NOT NULL DEFAULT 0 CHECK (version >= 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (organization_id, customer_number),
  UNIQUE (id, organization_id),
  FOREIGN KEY (merged_into_customer_id, organization_id)
    REFERENCES customers(id, organization_id) ON DELETE RESTRICT,
  CHECK (
    (status = 'merged' AND merged_into_customer_id IS NOT NULL) OR
    (status <> 'merged' AND merged_into_customer_id IS NULL)
  )
);

CREATE TABLE IF NOT EXISTS customer_addresses (
  id text PRIMARY KEY,
  organization_id text NOT NULL REFERENCES organizations(id) ON DELETE RESTRICT,
  customer_id text NOT NULL,
  label text NOT NULL,
  recipient_name text,
  line_one text NOT NULL,
  line_two text,
  city text NOT NULL,
  province text,
  postal_code text,
  country_code text NOT NULL DEFAULT 'PH',
  is_primary boolean NOT NULL DEFAULT false,
  version integer NOT NULL DEFAULT 0 CHECK (version >= 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz,
  FOREIGN KEY (customer_id, organization_id)
    REFERENCES customers(id, organization_id) ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS customer_notes (
  id text PRIMARY KEY,
  organization_id text NOT NULL REFERENCES organizations(id) ON DELETE RESTRICT,
  branch_id text NOT NULL,
  customer_id text NOT NULL,
  body text NOT NULL CHECK (char_length(body) BETWEEN 1 AND 2000),
  created_by_user_id text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz,
  FOREIGN KEY (branch_id, organization_id)
    REFERENCES branches(id, organization_id) ON DELETE RESTRICT,
  FOREIGN KEY (customer_id, organization_id)
    REFERENCES customers(id, organization_id) ON DELETE RESTRICT,
  FOREIGN KEY (created_by_user_id, organization_id)
    REFERENCES app_users(id, organization_id) ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS loyalty_accounts (
  id text PRIMARY KEY,
  organization_id text NOT NULL REFERENCES organizations(id) ON DELETE RESTRICT,
  customer_id text NOT NULL,
  status text NOT NULL DEFAULT 'active' CHECK (
    status IN ('active', 'disabled', 'closed', 'merged')
  ),
  points_balance bigint NOT NULL DEFAULT 0 CHECK (points_balance >= 0),
  lifetime_earned_points bigint NOT NULL DEFAULT 0
    CHECK (lifetime_earned_points >= 0),
  lifetime_redeemed_points bigint NOT NULL DEFAULT 0
    CHECK (lifetime_redeemed_points >= 0),
  version integer NOT NULL DEFAULT 0 CHECK (version >= 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  closed_at timestamptz,
  UNIQUE (organization_id, customer_id),
  UNIQUE (id, organization_id),
  FOREIGN KEY (customer_id, organization_id)
    REFERENCES customers(id, organization_id) ON DELETE RESTRICT
);

ALTER TABLE sales ADD COLUMN IF NOT EXISTS customer_id text;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'sales_customer_organization_fk'
  ) THEN
    ALTER TABLE sales
      ADD CONSTRAINT sales_customer_organization_fk
      FOREIGN KEY (customer_id, organization_id)
      REFERENCES customers(id, organization_id) ON DELETE RESTRICT;
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS loyalty_ledger_entries (
  id text PRIMARY KEY,
  organization_id text NOT NULL REFERENCES organizations(id) ON DELETE RESTRICT,
  branch_id text,
  account_id text NOT NULL,
  sale_id text,
  operation_id text NOT NULL,
  entry_type text NOT NULL CHECK (
    entry_type IN ('earn', 'redeem', 'adjustment', 'expiry', 'reversal',
                   'merge_in', 'merge_out')
  ),
  points_delta bigint NOT NULL CHECK (points_delta <> 0),
  balance_after bigint NOT NULL CHECK (balance_after >= 0),
  reason text NOT NULL,
  reference_type text,
  reference_id text,
  created_by_user_id text NOT NULL,
  occurred_at timestamptz NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (organization_id, operation_id),
  FOREIGN KEY (branch_id, organization_id)
    REFERENCES branches(id, organization_id) ON DELETE RESTRICT,
  FOREIGN KEY (account_id, organization_id)
    REFERENCES loyalty_accounts(id, organization_id) ON DELETE RESTRICT,
  FOREIGN KEY (sale_id, organization_id, branch_id)
    REFERENCES sales(id, organization_id, branch_id) ON DELETE RESTRICT,
  FOREIGN KEY (created_by_user_id, organization_id)
    REFERENCES app_users(id, organization_id) ON DELETE RESTRICT
);

CREATE INDEX IF NOT EXISTS customers_name_search_idx
  ON customers (organization_id, normalized_name, status);
CREATE INDEX IF NOT EXISTS customers_email_search_idx
  ON customers (organization_id, normalized_email)
  WHERE normalized_email IS NOT NULL;
CREATE INDEX IF NOT EXISTS customers_phone_search_idx
  ON customers (organization_id, normalized_phone)
  WHERE normalized_phone IS NOT NULL;
CREATE INDEX IF NOT EXISTS customer_notes_history_idx
  ON customer_notes (organization_id, branch_id, customer_id, created_at);
CREATE INDEX IF NOT EXISTS customer_sales_history_idx
  ON sales (organization_id, branch_id, customer_id, completed_at)
  WHERE customer_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS loyalty_ledger_history_idx
  ON loyalty_ledger_entries (organization_id, account_id, occurred_at);

COMMIT;
