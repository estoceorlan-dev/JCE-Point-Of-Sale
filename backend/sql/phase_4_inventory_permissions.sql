BEGIN;

INSERT INTO permissions (code, name, description)
VALUES (
  'inventory.adjustments.approve',
  'Approve inventory adjustments',
  'Approve inventory adjustments above the configured branch threshold.'
)
ON CONFLICT (code) DO UPDATE
SET name = EXCLUDED.name,
    description = EXCLUDED.description;

INSERT INTO role_permissions (role_id, permission_code, granted_at)
SELECT role.id, 'inventory.adjustments.approve', now()
FROM roles AS role
WHERE role.code = 'admin'
  AND role.is_active = true
  AND role.deleted_at IS NULL
ON CONFLICT (role_id, permission_code) DO NOTHING;

COMMIT;
