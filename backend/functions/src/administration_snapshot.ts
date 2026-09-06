import {PoolClient} from "pg";

import {StaffInviteError} from "./staff_invites";

export async function loadAdministrationSnapshot(
  client: PoolClient,
  input: {firebaseUid: string; organizationId: string},
) {
  await client.query("BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY");
  try {
    const snapshot = await readSnapshot(client, input);
    await client.query("COMMIT");
    return snapshot;
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  }
}

async function readSnapshot(
  client: PoolClient,
  input: {firebaseUid: string; organizationId: string},
) {
  const access = await client.query(
    `SELECT DISTINCT rp.permission_code FROM app_users au
     JOIN organizations o ON o.id = au.organization_id
       AND o.is_active = true AND o.deleted_at IS NULL
     JOIN user_role_assignments ura ON ura.user_id = au.id
       AND ura.organization_id = au.organization_id
       AND ura.branch_id IS NULL AND ura.revoked_at IS NULL
     JOIN roles r ON r.id = ura.role_id AND r.organization_id = au.organization_id
       AND r.is_active = true
       AND r.deleted_at IS NULL
     JOIN role_permissions rp ON rp.role_id = r.id
       AND rp.permission_code = ANY($3::text[])
     WHERE au.firebase_uid = $1 AND au.organization_id = $2
       AND au.status = 'active' AND au.deleted_at IS NULL`,
    [input.firebaseUid, input.organizationId, [
      "users.manage", "roles.manage", "branches.manage", "registers.manage",
      "products.manage",
    ]],
  );
  if (access.rows.length === 0) {
    throw new StaffInviteError(
      "permission-denied",
      "An organization-wide administration permission is required.",
    );
  }
  const permissions = new Set<string>(access.rows.map((row) => row.permission_code));
  const accessDirectory = permissions.has("users.manage") || permissions.has("roles.manage");
  const registerDirectory = accessDirectory || permissions.has("branches.manage") ||
    permissions.has("registers.manage");
  const read = (sql: string, allowed = true) => allowed ?
    client.query(sql, [input.organizationId]) : Promise.resolve({rows: []});

  const [branches, users, roles, rolePermissions, assignments, registers,
    taxCategories] = await Promise.all([
    read(
      `SELECT id, organization_id AS "organizationId", code, name, timezone,
       address_line_one AS "addressLineOne", address_line_two AS "addressLineTwo",
       city, province, postal_code AS "postalCode", phone, email,
       receipt_display_name AS "receiptDisplayName", is_active AS "isActive",
       allow_negative_stock AS "allowNegativeStock",
       adjustment_approval_threshold_milli AS "adjustmentApprovalThresholdMilli",
       allow_multiple_open_shifts_per_user AS "allowMultipleOpenShiftsPerUser",
       allow_sales_without_open_shift AS "allowSalesWithoutOpenShift",
       cash_discrepancy_approval_threshold_minor AS "cashDiscrepancyApprovalThresholdMinor",
       discount_approval_threshold_basis_points AS "discountApprovalThresholdBasisPoints",
       return_approval_threshold_minor AS "returnApprovalThresholdMinor",
       void_window_minutes AS "voidWindowMinutes",
       transfer_approval_threshold_milli AS "transferApprovalThresholdMilli",
       version, created_at AS "createdAt", updated_at AS "updatedAt",
       deleted_at AS "deletedAt"
       FROM branches WHERE organization_id = $1 ORDER BY id`,
    ),
    read(
      `SELECT id, organization_id AS "organizationId", firebase_uid AS "firebaseUid",
       email, display_name AS "displayName", status, invited_at AS "invitedAt",
       activated_at AS "activatedAt", version, created_at AS "createdAt",
       updated_at AS "updatedAt", deleted_at AS "deletedAt"
       FROM app_users WHERE organization_id = $1 ORDER BY id`,
      accessDirectory,
    ),
    read(
      `SELECT id, organization_id AS "organizationId", code, name, description,
       is_active AS "isActive", version, created_at AS "createdAt",
       updated_at AS "updatedAt", deleted_at AS "deletedAt"
       FROM roles WHERE organization_id = $1 ORDER BY id`,
      accessDirectory,
    ),
    read(
      `SELECT rp.role_id AS "roleId", rp.permission_code AS "permissionCode",
       rp.granted_at AS "grantedAt"
       FROM role_permissions rp JOIN roles r ON r.id = rp.role_id
       WHERE r.organization_id = $1 ORDER BY rp.role_id, rp.permission_code`,
      accessDirectory,
    ),
    read(
      `SELECT id, organization_id AS "organizationId", branch_id AS "branchId",
       user_id AS "userId", role_id AS "roleId", version,
       assigned_at AS "assignedAt", updated_at AS "updatedAt",
       revoked_at AS "revokedAt"
       FROM user_role_assignments WHERE organization_id = $1 ORDER BY id`,
      accessDirectory,
    ),
    read(
      `SELECT id, organization_id AS "organizationId", branch_id AS "branchId",
       code, name, assigned_device_id AS "assignedDeviceId",
       assigned_by_user_id AS "assignedByUserId", assigned_at AS "assignedAt",
       scanner_type AS "scannerType",
       scanner_inter_character_timeout_ms AS "scannerInterCharacterTimeoutMs",
       scanner_duplicate_suppression_ms AS "scannerDuplicateSuppressionMs",
       printer_type AS "printerType", printer_address AS "printerAddress",
       printer_port AS "printerPort", printer_paper_width_mm AS "printerPaperWidthMm",
       cash_drawer_enabled AS "cashDrawerEnabled", cash_drawer_pin AS "cashDrawerPin",
       is_active AS "isActive", version, created_at AS "createdAt",
       updated_at AS "updatedAt", deleted_at AS "deletedAt"
       FROM registers WHERE organization_id = $1 ORDER BY id`,
      registerDirectory,
    ),
    read(
      `SELECT id, organization_id AS "organizationId", code, name,
       rate_basis_points AS "rateBasisPoints", is_inclusive AS "isInclusive",
       is_active AS "isActive", version, created_at AS "createdAt",
       updated_at AS "updatedAt", deleted_at AS "deletedAt"
       FROM tax_categories WHERE organization_id = $1 ORDER BY id`,
      permissions.has("products.manage"),
    ),
  ]);

  return {
    schemaVersion: 1,
    organizationId: input.organizationId,
    permissions: [...permissions].sort(),
    branches: serializeRows(branches.rows),
    users: serializeRows(users.rows),
    roles: serializeRows(roles.rows),
    rolePermissions: serializeRows(rolePermissions.rows),
    assignments: serializeRows(assignments.rows),
    registers: serializeRows(registers.rows),
    taxCategories: serializeRows(taxCategories.rows),
    generatedAt: new Date().toISOString(),
  };
}

function serializeRows(rows: Record<string, unknown>[]) {
  return rows.map((row) => Object.fromEntries(Object.entries(row).map(
    ([key, value]) => [key, value instanceof Date ? value.toISOString() : value],
  )));
}
