INSERT INTO permissions (code, name, description, updated_at)
VALUES
  ('dashboard.view', 'View dashboard', 'View operational dashboard summaries.', now()),
  ('sales.process', 'Process sales', 'Open shifts and complete point-of-sale transactions.', now()),
  ('sales.discounts.approve', 'Approve sale discounts', 'Approve discounts above branch limits.', now()),
  ('products.manage', 'Manage products', 'Create, update, archive, price, and image products.', now()),
  ('inventory.manage', 'Manage inventory', 'Create stock locations and post inventory movements.', now()),
  ('inventory.adjustments.approve', 'Approve inventory adjustments', 'Approve adjustments above branch limits.', now()),
  ('registers.manage', 'Manage registers', 'Create registers, assign devices, and configure shift policy.', now()),
  ('shifts.discrepancies.approve', 'Approve shift discrepancies', 'Approve shift discrepancies and assisted closures.', now()),
  ('transfers.approve', 'Approve transfers', 'Approve branch stock transfers.', now()),
  ('purchases.create', 'Create purchases', 'Create purchase orders and receiving records.', now()),
  ('reports.view', 'View reports', 'View permitted operational reports.', now()),
  ('audit_logs.view', 'View audit logs', 'View scoped audit history.', now()),
  ('users.manage', 'Manage users', 'Manage user access and assignments.', now()),
  ('settings.manage', 'Manage settings', 'Manage organization and branch settings.', now())
ON CONFLICT (code) DO UPDATE
SET name = EXCLUDED.name,
    description = EXCLUDED.description,
    updated_at = now();
