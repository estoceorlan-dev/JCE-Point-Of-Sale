BEGIN;

INSERT INTO permissions (code, name, description)
VALUES
  (
    'registers.manage',
    'Manage registers',
    'Create branch registers, assign devices, and configure shift policy.'
  ),
  (
    'shifts.discrepancies.approve',
    'Approve shift discrepancies',
    'Approve cash discrepancies and manager-assisted shift closure.'
  )
ON CONFLICT (code) DO UPDATE
SET name = EXCLUDED.name,
    description = EXCLUDED.description;

INSERT INTO role_permissions (role_id, permission_code, granted_at)
SELECT role.id, permission.code, now()
FROM roles AS role
CROSS JOIN (
  VALUES
    ('registers.manage'),
    ('shifts.discrepancies.approve')
) AS permission(code)
WHERE role.code = 'admin'
  AND role.is_active = true
  AND role.deleted_at IS NULL
ON CONFLICT (role_id, permission_code) DO NOTHING;

COMMIT;
