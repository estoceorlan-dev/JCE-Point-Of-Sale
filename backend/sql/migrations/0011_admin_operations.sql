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

INSERT INTO role_permissions (role_id, permission_code, granted_at)
SELECT r.id, p.code, now()
FROM roles r
CROSS JOIN permissions p
WHERE lower(r.code) IN ('owner', 'admin')
  AND p.code IN ('branches.manage', 'roles.manage')
  AND r.is_active = true
  AND r.deleted_at IS NULL
ON CONFLICT DO NOTHING;

CREATE INDEX IF NOT EXISTS branches_directory_idx
  ON branches (organization_id, is_active, lower(name), code);

-- Fail on legacy duplicates rather than silently changing codes used by history.
-- Run the normalized-code preflight before applying this migration.
CREATE UNIQUE INDEX IF NOT EXISTS branches_normalized_code_unique
  ON branches (organization_id, upper(btrim(code)));
