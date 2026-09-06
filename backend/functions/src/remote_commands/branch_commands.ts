import {PoolClient} from "pg";

import {
  AuthorizedCommand,
  CommandResult,
  RemoteCommandError,
  optionalInteger,
  optionalString,
  requiredBoolean,
  requiredInteger,
  requiredString,
} from "./command_types";

export async function applyBranchCommand(
  client: PoolClient,
  command: AuthorizedCommand,
): Promise<CommandResult> {
  const administrative = [
    "branch.create",
    "branch.update",
    "branch.archive",
    "branch.restore",
  ].includes(command.commandType);
  if (!administrative && command.aggregateId !== command.branchId) {
    throw new RemoteCommandError("invalid-argument", "Branch IDs do not match.");
  }
  if (command.commandType === "branch.create") {
    const id = requiredString(command.payload, "id");
    if (id !== command.aggregateId) {
      throw new RemoteCommandError("invalid-argument", "Branch IDs do not match.");
    }
    const profile = branchProfile(command);
    const result = await client.query(
      `INSERT INTO branches (
         id, organization_id, code, name, timezone, address_line_one,
         address_line_two, city, province, postal_code, phone, email,
         receipt_display_name, is_active, version, created_at, updated_at
       ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12,
                 $13, true, 0, now(), now())
       RETURNING id, organization_id AS "organizationId", code, name,
         timezone, address_line_one AS "addressLineOne",
         address_line_two AS "addressLineTwo", city, province,
         postal_code AS "postalCode", phone, email,
         receipt_display_name AS "receiptDisplayName", is_active AS "isActive",
         version, created_at AS "createdAt", updated_at AS "updatedAt",
         deleted_at AS "deletedAt"`,
      [id, command.organizationId, profile.code, profile.name, profile.timezone,
        profile.addressLineOne, profile.addressLineTwo, profile.city,
        profile.province, profile.postalCode, profile.phone, profile.email,
        profile.receiptDisplayName],
    );
    return {branch: result.rows[0]};
  }
  if (command.commandType === "branch.update") {
    const profile = branchProfile(command);
    const expectedVersion = requiredInteger(command.payload, "expectedVersion");
    const result = await client.query(
      `UPDATE branches SET code = $4, name = $5, timezone = $6,
         address_line_one = $7, address_line_two = $8, city = $9,
         province = $10, postal_code = $11, phone = $12, email = $13,
         receipt_display_name = $14, version = version + 1, updated_at = now()
       WHERE id = $1 AND organization_id = $2 AND version = $3
         AND is_active = true AND deleted_at IS NULL
       RETURNING id, organization_id AS "organizationId", code, name,
         timezone, address_line_one AS "addressLineOne",
         address_line_two AS "addressLineTwo", city, province,
         postal_code AS "postalCode", phone, email,
         receipt_display_name AS "receiptDisplayName", is_active AS "isActive",
         version, created_at AS "createdAt", updated_at AS "updatedAt",
         deleted_at AS "deletedAt"`,
      [command.aggregateId, command.organizationId, expectedVersion,
        profile.code, profile.name, profile.timezone, profile.addressLineOne,
        profile.addressLineTwo, profile.city, profile.province,
        profile.postalCode, profile.phone, profile.email,
        profile.receiptDisplayName],
    );
    if (result.rowCount !== 1) {
      throw new RemoteCommandError("aborted", "The branch changed. Refresh and retry.");
    }
    return {branch: result.rows[0]};
  }
  if (command.commandType === "branch.archive" ||
      command.commandType === "branch.restore") {
    // Serialize organization-wide lifecycle decisions, not only each branch.
    await client.query("SELECT pg_advisory_xact_lock(hashtextextended($1, 0))",
      [`branch-administration:${command.organizationId}`]);
    const archived = command.commandType === "branch.archive";
    const expectedVersion = requiredInteger(command.payload, "expectedVersion");
    if (archived) await requireBranchCanArchive(client, command);
    const result = await client.query(
      `UPDATE branches SET is_active = $4,
         deleted_at = CASE WHEN $4 THEN NULL ELSE now() END,
         version = version + 1, updated_at = now()
       WHERE id = $1 AND organization_id = $2 AND version = $3
       RETURNING id, organization_id AS "organizationId", code, name,
         timezone, address_line_one AS "addressLineOne",
         address_line_two AS "addressLineTwo", city, province,
         postal_code AS "postalCode", phone, email,
         receipt_display_name AS "receiptDisplayName", is_active AS "isActive",
         version, created_at AS "createdAt", updated_at AS "updatedAt",
         deleted_at AS "deletedAt"`,
      [command.aggregateId, command.organizationId, expectedVersion, !archived],
    );
    if (result.rowCount !== 1) {
      throw new RemoteCommandError("aborted", "The branch changed. Refresh and retry.");
    }
    return {branch: result.rows[0]};
  }
  if (command.commandType === "branch.update_name") {
    const name = requiredString(command.payload, "name");
    if (name.length < 2 || name.length > 80) {
      throw new RemoteCommandError("invalid-argument", "The branch name is invalid.");
    }
    const result = await client.query(
      `UPDATE branches SET name = $3, version = version + 1, updated_at = now()
       WHERE id = $1 AND organization_id = $2 AND is_active = true AND deleted_at IS NULL
       RETURNING id, version`,
      [command.branchId, command.organizationId, name],
    );
    if (result.rowCount !== 1) {
      throw new RemoteCommandError("not-found", "The active branch does not exist.");
    }
    return {branch: result.rows[0]};
  }
  if (command.commandType === "branch.shift_policy.update") {
    const threshold = optionalInteger(
      command.payload,
      "cashDiscrepancyApprovalThresholdMinor",
    );
    if (threshold !== null && threshold < 0) {
      throw new RemoteCommandError("invalid-argument", "The cash threshold is invalid.");
    }
    const result = await client.query(
      `UPDATE branches SET
         allow_multiple_open_shifts_per_user = $3,
         allow_sales_without_open_shift = $4,
         cash_discrepancy_approval_threshold_minor = $5,
         version = version + 1,
         updated_at = now()
       WHERE id = $1 AND organization_id = $2 AND is_active = true AND deleted_at IS NULL
       RETURNING id, version`,
      [
        command.branchId,
        command.organizationId,
        requiredBoolean(command.payload, "allowMultipleOpenShiftsPerUser"),
        requiredBoolean(command.payload, "allowSalesWithoutOpenShift"),
        threshold,
      ],
    );
    if (result.rowCount !== 1) {
      throw new RemoteCommandError("not-found", "The active branch does not exist.");
    }
    return {branch: result.rows[0]};
  }

  if (command.commandType === "branch.discount_policy.update") {
    const threshold = requiredInteger(
      command.payload,
      "approvalThresholdBasisPoints",
    );
    if (threshold < 0 || threshold > 10000) {
      throw new RemoteCommandError("invalid-argument", "The discount threshold is invalid.");
    }
    const result = await client.query(
      `UPDATE branches SET
         discount_approval_threshold_basis_points = $3,
         version = version + 1,
         updated_at = now()
       WHERE id = $1 AND organization_id = $2 AND is_active = true AND deleted_at IS NULL
       RETURNING id, version`,
      [command.branchId, command.organizationId, threshold],
    );
    if (result.rowCount !== 1) {
      throw new RemoteCommandError("not-found", "The active branch does not exist.");
    }
    return {branch: result.rows[0]};
  }

  if (command.commandType === "branch.correction_policy.update") {
    const threshold = optionalInteger(
      command.payload,
      "returnApprovalThresholdMinor",
    );
    const voidWindowMinutes = requiredInteger(
      command.payload,
      "voidWindowMinutes",
    );
    if ((threshold !== null && threshold < 0) || voidWindowMinutes < 0) {
      throw new RemoteCommandError(
        "invalid-argument",
        "The correction policy is invalid.",
      );
    }
    const result = await client.query(
      `UPDATE branches SET
         return_approval_threshold_minor = $3,
         void_window_minutes = $4,
         version = version + 1,
         updated_at = now()
       WHERE id = $1 AND organization_id = $2
         AND is_active = true AND deleted_at IS NULL
       RETURNING id, version`,
      [
        command.branchId,
        command.organizationId,
        threshold,
        voidWindowMinutes,
      ],
    );
    if (result.rowCount !== 1) {
      throw new RemoteCommandError(
        "not-found",
        "The active branch does not exist.",
      );
    }
    return {branch: result.rows[0]};
  }

  if (command.commandType === "branch.transfer_policy.configure") {
    const threshold = optionalInteger(
      command.payload,
      "approvalThresholdMilli",
    );
    if (threshold !== null && threshold < 0) {
      throw new RemoteCommandError(
        "invalid-argument",
        "The transfer approval threshold is invalid.",
      );
    }
    const result = await client.query(
      `UPDATE branches SET
         transfer_approval_threshold_milli = $3,
         version = version + 1,
         updated_at = now()
       WHERE id = $1 AND organization_id = $2
         AND is_active = true AND deleted_at IS NULL
       RETURNING id, version`,
      [command.branchId, command.organizationId, threshold],
    );
    if (result.rowCount !== 1) {
      throw new RemoteCommandError("not-found", "The active branch does not exist.");
    }
    return {branch: result.rows[0]};
  }

  throw new RemoteCommandError(
    "invalid-argument",
    `Unsupported branch command: ${command.commandType}.`,
  );
}

function branchProfile(command: AuthorizedCommand) {
  const code = requiredString(command.payload, "code").toUpperCase();
  const name = requiredString(command.payload, "name");
  const timezone = requiredString(command.payload, "timezone");
  if (!/^[A-Z0-9][A-Z0-9-]{1,19}$/.test(code) ||
      name.length < 2 || name.length > 80) {
    throw new RemoteCommandError("invalid-argument", "The branch profile is invalid.");
  }
  try {
    new Intl.DateTimeFormat("en", {timeZone: timezone}).format();
  } catch {
    throw new RemoteCommandError("invalid-argument", "Use a valid IANA timezone.");
  }
  const email = optionalString(command.payload, "email")?.toLowerCase() ?? null;
  const phone = optionalString(command.payload, "phone");
  const receiptDisplayName = optionalString(command.payload, "receiptDisplayName");
  if ((email !== null && (email.length > 254 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email))) ||
      (phone !== null && !/^\+?[0-9 ()-]{7,30}$/.test(phone)) ||
      (receiptDisplayName !== null && receiptDisplayName.length > 80)) {
    throw new RemoteCommandError("invalid-argument", "Invalid contact or receipt display details.");
  }
  return {
    code,
    name,
    timezone,
    addressLineOne: optionalString(command.payload, "addressLineOne"),
    addressLineTwo: optionalString(command.payload, "addressLineTwo"),
    city: optionalString(command.payload, "city"),
    province: optionalString(command.payload, "province"),
    postalCode: optionalString(command.payload, "postalCode"),
    phone,
    email,
    receiptDisplayName,
  };
}

async function requireBranchCanArchive(
  client: PoolClient,
  command: AuthorizedCommand,
): Promise<void> {
  if (command.aggregateId === command.branchId) {
    throw new RemoteCommandError("failed-precondition", "Switch branches before archiving the active branch.");
  }
  const target = await client.query(
    "SELECT id FROM branches WHERE id = $1 AND organization_id = $2 FOR UPDATE",
    [command.aggregateId, command.organizationId],
  );
  if (target.rowCount !== 1) {
    throw new RemoteCommandError("not-found", "The branch does not exist in this organization.");
  }
  const result = await client.query(
    `SELECT
       (SELECT count(*) FROM branches WHERE organization_id = $1
          AND is_active = true AND deleted_at IS NULL) AS active_count,
       EXISTS (SELECT 1 FROM shifts WHERE organization_id = $1 AND branch_id = $2
          AND status = 'open') AS has_shift,
       EXISTS (SELECT 1 FROM stock_counts WHERE organization_id = $1 AND branch_id = $2
          AND status = 'in_progress') AS has_count,
       EXISTS (SELECT 1 FROM stock_transfers WHERE organization_id = $1
          AND (source_branch_id = $2 OR destination_branch_id = $2)
          AND status IN ('draft', 'submitted', 'approved', 'shipped')) AS has_transfer`,
    [command.organizationId, command.aggregateId],
  );
  const guard = result.rows[0];
  if (Number(guard.active_count) <= 1 || guard.has_shift || guard.has_count ||
      guard.has_transfer) {
    throw new RemoteCommandError("failed-precondition", "Resolve active branch operations before archiving.");
  }
}
