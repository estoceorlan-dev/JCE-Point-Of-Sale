import {PoolClient} from "pg";

import {
  AuthorizedCommand,
  CommandResult,
  RemoteCommandError,
  optionalInteger,
  requiredBoolean,
  requiredInteger,
  requiredString,
} from "./command_types";

export async function applyBranchCommand(
  client: PoolClient,
  command: AuthorizedCommand,
): Promise<CommandResult> {
  if (command.aggregateId !== command.branchId) {
    throw new RemoteCommandError("invalid-argument", "Branch IDs do not match.");
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
