ALTER TABLE branches ADD COLUMN IF NOT EXISTS address_line_one text;
ALTER TABLE branches ADD COLUMN IF NOT EXISTS address_line_two text;
ALTER TABLE branches ADD COLUMN IF NOT EXISTS city text;
ALTER TABLE branches ADD COLUMN IF NOT EXISTS province text;
ALTER TABLE branches ADD COLUMN IF NOT EXISTS postal_code text;
ALTER TABLE branches ADD COLUMN IF NOT EXISTS phone text;
ALTER TABLE branches ADD COLUMN IF NOT EXISTS email text;
ALTER TABLE branches ADD COLUMN IF NOT EXISTS receipt_display_name text;
ALTER TABLE app_users ADD COLUMN IF NOT EXISTS invited_at timestamptz;
ALTER TABLE app_users ADD COLUMN IF NOT EXISTS activated_at timestamptz;

INSERT INTO permissions (code, name, description, created_at, updated_at)
VALUES
  ('branches.manage', 'Manage branches', 'Create, edit, archive, and restore branches.', now(), now()),
  ('roles.manage', 'Manage roles', 'Configure roles and permission grants.', now(), now())
ON CONFLICT (code) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  updated_at = now();

-- Seed permission definitions only. Role names do not authorize access.
-- Grant these permissions separately to explicitly approved organization/role
-- IDs through the controlled administration provisioning workflow.

CREATE INDEX IF NOT EXISTS branches_directory_idx
  ON branches (organization_id, is_active, lower(name), code);

-- Fail on legacy duplicates rather than silently changing codes used by history.
-- Run the normalized-code preflight before applying this migration.
CREATE UNIQUE INDEX IF NOT EXISTS branches_normalized_code_unique
  ON branches (organization_id, upper(btrim(code)));
