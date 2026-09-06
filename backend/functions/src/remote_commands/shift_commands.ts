import {randomUUID} from "node:crypto";
import {PoolClient} from "pg";
import {administerRegister} from "./register_administration_commands";

import {
  AuthorizedCommand,
  CommandResult,
  RemoteCommandError,
  asObject,
  optionalString,
  optionalTimestamp,
  requiredBoolean,
  requiredInteger,
  requiredString,
} from "./command_types";

type ShiftRow = {
  id: string;
  register_id: string;
  opening_cash_minor: string;
  opened_by_user_id: string;
  version: number;
};

export async function applyShiftCommand(
  client: PoolClient,
  command: AuthorizedCommand,
): Promise<CommandResult> {
  if (["register.update", "register.archive", "register.restore", "register.unassign_device"]
    .includes(command.commandType)) return administerRegister(client, command);
  if (command.commandType === "register.create") return createRegister(client, command);
  if (command.commandType === "register.assign_device") return assignRegisterDevice(client, command);
  if (command.commandType === "register.hardware.configure") return configureRegisterHardware(client, command);
  if (command.commandType === "shift.open") return openShift(client, command);
  if (command.commandType === "shift.cash_movement") return postCashMovement(client, command);
  if (command.commandType === "shift.close") return closeShift(client, command);
  throw new RemoteCommandError("invalid-argument", `Unsupported shift command: ${command.commandType}.`);
}

async function configureRegisterHardware(
  client: PoolClient,
  command: AuthorizedCommand,
): Promise<CommandResult> {
  const payload = command.payload;
  const registerId = requiredString(payload, "registerId");
  const scannerType = requiredString(payload, "scannerType");
  const scannerTimeout = requiredInteger(payload, "scannerInterCharacterTimeoutMs");
  const duplicateSuppression = requiredInteger(payload, "scannerDuplicateSuppressionMs");
  const printerType = requiredString(payload, "printerType");
  const printerAddress = optionalString(payload, "printerAddress");
  const printerPort = requiredInteger(payload, "printerPort");
  const paperWidth = requiredInteger(payload, "printerPaperWidthMm");
  const drawerEnabled = requiredBoolean(payload, "cashDrawerEnabled");
  const drawerPin = requiredInteger(payload, "cashDrawerPin");
  const expectedVersion = requiredInteger(payload, "expectedVersion");
  if (registerId !== command.aggregateId ||
      !["disabled", "keyboard_wedge", "camera"].includes(scannerType) ||
      scannerTimeout < 20 || scannerTimeout > 1000 ||
      duplicateSuppression < 0 || duplicateSuppression > 5000 ||
      !["screen", "network_esc_pos"].includes(printerType) ||
      (printerType === "network_esc_pos" && printerAddress === null) ||
      printerPort < 1 || printerPort > 65535 ||
      ![58, 80].includes(paperWidth) || ![0, 1].includes(drawerPin) ||
      (drawerEnabled && printerType !== "network_esc_pos") ||
      expectedVersion < 0) {
    throw new RemoteCommandError(
      "invalid-argument",
      "The register hardware configuration is invalid.",
    );
  }
  const result = await client.query(
    `UPDATE registers SET
       scanner_type = $4,
       scanner_inter_character_timeout_ms = $5,
       scanner_duplicate_suppression_ms = $6,
       printer_type = $7,
       printer_address = $8,
       printer_port = $9,
       printer_paper_width_mm = $10,
       cash_drawer_enabled = $11,
       cash_drawer_pin = $12,
       version = version + 1,
       updated_at = now()
     WHERE id = $1 AND organization_id = $2 AND branch_id = $3
       AND version = $13 AND is_active = true AND deleted_at IS NULL
     RETURNING id, code, name, assigned_device_id, scanner_type,
       scanner_inter_character_timeout_ms, scanner_duplicate_suppression_ms,
       printer_type, printer_address, printer_port, printer_paper_width_mm,
       cash_drawer_enabled, cash_drawer_pin, is_active, version`,
    [
      registerId,
      command.organizationId,
      command.branchId,
      scannerType,
      scannerTimeout,
      duplicateSuppression,
      printerType,
      printerAddress,
      printerPort,
      paperWidth,
      drawerEnabled,
      drawerPin,
      expectedVersion,
    ],
  );
  if (result.rowCount !== 1) {
    throw new RemoteCommandError(
      "aborted",
      "The register hardware configuration changed. Refresh and retry.",
    );
  }
  return {register: result.rows[0]};
}

async function createRegister(
  client: PoolClient,
  command: AuthorizedCommand,
): Promise<CommandResult> {
  const id = requiredString(command.payload, "id");
  if (id !== command.aggregateId) {
    throw new RemoteCommandError("invalid-argument", "Register IDs do not match.");
  }
  const result = await client.query(
    `INSERT INTO registers (
       id, organization_id, branch_id, code, name, is_active,
       version, created_at, updated_at
     ) VALUES ($1, $2, $3, $4, $5, true, 0, now(), now())
     RETURNING id, code, name, is_active, version`,
    [
      id,
      command.organizationId,
      command.branchId,
      requiredString(command.payload, "code"),
      requiredString(command.payload, "name"),
    ],
  );
  return {register: result.rows[0]};
}

async function assignRegisterDevice(
  client: PoolClient,
  command: AuthorizedCommand,
): Promise<CommandResult> {
  const registerId = requiredString(command.payload, "registerId");
  const deviceId = requiredString(command.payload, "deviceId");
  const expectedVersion = requiredInteger(command.payload, "expectedVersion");
  if (registerId !== command.aggregateId || expectedVersion < 0) {
    throw new RemoteCommandError("invalid-argument", "The register assignment is invalid.");
  }
  const device = await client.query(
    `SELECT 1 FROM devices
     WHERE id = $1 AND organization_id = $2 AND branch_id = $3 AND disabled_at IS NULL`,
    [deviceId, command.organizationId, command.branchId],
  );
  if (device.rowCount !== 1) {
    throw new RemoteCommandError("not-found", "The active branch device does not exist.");
  }
  const result = await client.query(
    `UPDATE registers SET
       assigned_device_id = $4,
       assigned_by_user_id = $5,
       assigned_at = now(),
       version = version + 1,
       updated_at = now()
     WHERE id = $1 AND organization_id = $2 AND branch_id = $3
       AND version = $6 AND is_active = true AND deleted_at IS NULL
       AND NOT EXISTS (
         SELECT 1 FROM shifts s
         WHERE s.register_id = registers.id
           AND s.organization_id = registers.organization_id
           AND s.branch_id = registers.branch_id
           AND s.status = 'open'
       )
     RETURNING id, assigned_device_id, version`,
    [
      registerId,
      command.organizationId,
      command.branchId,
      deviceId,
      command.actorUserId,
      expectedVersion,
    ],
  );
  if (result.rowCount !== 1) {
    throw new RemoteCommandError(
      "aborted",
      "The register changed or has an open shift. Refresh and retry.",
    );
  }
  return {register: result.rows[0]};
}

async function openShift(
  client: PoolClient,
  command: AuthorizedCommand,
): Promise<CommandResult> {
  const payload = command.payload;
  const shiftId = requiredString(payload, "id");
  const registerId = requiredString(payload, "registerId");
  const deviceId = requiredString(payload, "deviceId");
  const openingCashMinor = requiredInteger(payload, "openingCashMinor");
  if (shiftId !== command.aggregateId || openingCashMinor < 0) {
    throw new RemoteCommandError("invalid-argument", "The shift opening is invalid.");
  }
  const scope = await client.query<{allow_multiple_open_shifts_per_user: boolean}>(
    `
      SELECT b.allow_multiple_open_shifts_per_user
      FROM registers r
      INNER JOIN branches b ON b.id = r.branch_id AND b.organization_id = r.organization_id
      WHERE r.id = $1 AND r.organization_id = $2 AND r.branch_id = $3
        AND r.assigned_device_id = $4 AND r.is_active = true AND r.deleted_at IS NULL
        AND b.is_active = true AND b.deleted_at IS NULL
        AND EXISTS (
          SELECT 1 FROM devices d
          WHERE d.id = $4 AND d.organization_id = r.organization_id
            AND d.branch_id = r.branch_id AND d.disabled_at IS NULL
        )
      FOR UPDATE OF r
    `,
    [registerId, command.organizationId, command.branchId, deviceId],
  );
  if (scope.rowCount !== 1) {
    throw new RemoteCommandError("permission-denied", "The device is not assigned to this register.");
  }
  if (!scope.rows[0].allow_multiple_open_shifts_per_user) {
    const userShift = await client.query(
      `SELECT id FROM shifts WHERE organization_id = $1 AND branch_id = $2
       AND opened_by_user_id = $3 AND status = 'open' LIMIT 1`,
      [command.organizationId, command.branchId, command.actorUserId],
    );
    if (userShift.rowCount !== 0) {
      throw new RemoteCommandError("failed-precondition", "The user already has an open shift.");
    }
  }
  const openedAt = optionalTimestamp(payload, "openedAt") ?? new Date();
  const result = await client.query(
    `
      INSERT INTO shifts (
        id, organization_id, branch_id, register_id, device_id, operation_id,
        status, opening_cash_minor, opening_notes, opened_by_user_id,
        opened_at, version, created_at, updated_at
      ) VALUES ($1, $2, $3, $4, $5, $6, 'open', $7, $8, $9, $10, 0, now(), now())
      RETURNING id, status, version, opened_at
    `,
    [shiftId, command.organizationId, command.branchId, registerId, deviceId, command.operationId, openingCashMinor, optionalString(payload, "notes"), command.actorUserId, openedAt],
  );
  return {shift: result.rows[0]};
}

async function postCashMovement(
  client: PoolClient,
  command: AuthorizedCommand,
): Promise<CommandResult> {
  const id = requiredString(command.payload, "id");
  const shiftId = requiredString(command.payload, "shiftId");
  const movementType = requiredString(command.payload, "type");
  const amountMinor = requiredInteger(command.payload, "amountMinor");
  if (shiftId !== command.aggregateId) {
    throw new RemoteCommandError("invalid-argument", "Shift IDs do not match.");
  }
  const validAmount = movementType === "cash_in" ? amountMinor > 0 :
    movementType === "correction" ? amountMinor !== 0 :
      (movementType === "cash_out" || movementType === "payout") && amountMinor < 0;
  if (!validAmount) {
    throw new RemoteCommandError("invalid-argument", "The cash movement amount is invalid.");
  }
  const shift = await client.query<{register_id: string}>(
    `SELECT register_id FROM shifts
     WHERE id = $1 AND organization_id = $2 AND branch_id = $3 AND status = 'open'
     FOR UPDATE`,
    [shiftId, command.organizationId, command.branchId],
  );
  if (shift.rowCount !== 1) {
    throw new RemoteCommandError("failed-precondition", "The shift is not open.");
  }
  const occurredAt = optionalTimestamp(command.payload, "occurredAt") ?? new Date();
  const result = await client.query(
    `INSERT INTO cash_movements (
       id, organization_id, branch_id, register_id, shift_id, operation_id,
       movement_type, amount_minor, reason, created_by_user_id, occurred_at,
       version, created_at, updated_at
     ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, 0, now(), now())
     RETURNING id, shift_id, movement_type, amount_minor, occurred_at, version`,
    [
      id,
      command.organizationId,
      command.branchId,
      shift.rows[0].register_id,
      shiftId,
      command.operationId,
      movementType,
      amountMinor,
      requiredString(command.payload, "reason"),
      command.actorUserId,
      occurredAt,
    ],
  );
  return {cashMovement: result.rows[0]};
}

async function closeShift(
  client: PoolClient,
  command: AuthorizedCommand,
): Promise<CommandResult> {
  const payload = command.payload;
  const shiftId = requiredString(payload, "shiftId");
  if (shiftId !== command.aggregateId) throw new RemoteCommandError("invalid-argument", "Shift IDs do not match.");
  const counted = asObject(payload.countedAmountsMinor, "countedAmountsMinor");
  const methods = ["cash", "card", "e_wallet"] as const;
  const countedAmounts = Object.fromEntries(methods.map((method) => {
    const amount = requiredInteger(counted, method);
    if (amount < 0) throw new RemoteCommandError("invalid-argument", "Shift counts cannot be negative.");
    return [method, amount];
  })) as Record<typeof methods[number], number>;
  const shiftResult = await client.query<ShiftRow>(
    `SELECT id, register_id, opening_cash_minor, opened_by_user_id, version
     FROM shifts WHERE id = $1 AND organization_id = $2 AND branch_id = $3 AND status = 'open'
     FOR UPDATE`,
    [shiftId, command.organizationId, command.branchId],
  );
  if (shiftResult.rowCount !== 1) throw new RemoteCommandError("failed-precondition", "The shift is not open.");
  const shift = shiftResult.rows[0];
  const approvedByUserId = optionalString(payload, "approvedByUserId");
  if (shift.opened_by_user_id !== command.actorUserId) {
    requireShiftApproval(command, approvedByUserId);
  }
  const movementResult = await client.query<{total: string}>(
    `SELECT COALESCE(sum(amount_minor), 0)::text AS total FROM cash_movements WHERE shift_id = $1`,
    [shiftId],
  );
  const paymentResult = await client.query<{payment_method: string; total: string}>(
    `SELECT payment_method, COALESCE(sum(applied_amount_minor), 0)::text AS total
     FROM payments WHERE shift_id = $1 GROUP BY payment_method`,
    [shiftId],
  );
  const paymentTotals: Record<string, number> = {cash: 0, card: 0, e_wallet: 0};
  for (const row of paymentResult.rows) paymentTotals[row.payment_method] = Number(row.total);
  const expected = {
    cash: Number(shift.opening_cash_minor) + Number(movementResult.rows[0].total) + paymentTotals.cash,
    card: paymentTotals.card,
    e_wallet: paymentTotals.e_wallet,
  };
  const discrepancy = countedAmounts.cash - expected.cash;
  const branchResult = await client.query<{cash_discrepancy_approval_threshold_minor: string | null}>(
    `SELECT cash_discrepancy_approval_threshold_minor FROM branches WHERE id = $1 AND organization_id = $2`,
    [command.branchId, command.organizationId],
  );
  const thresholdValue = branchResult.rows[0].cash_discrepancy_approval_threshold_minor;
  if (thresholdValue !== null && Math.abs(discrepancy) > Number(thresholdValue)) {
    requireShiftApproval(command, approvedByUserId);
  }
  const closedAt = optionalTimestamp(payload, "closedAt") ?? new Date();
  for (const method of methods) {
    await client.query(
      `INSERT INTO shift_counts (
        id, organization_id, branch_id, shift_id, payment_method,
        expected_amount_minor, counted_amount_minor, discrepancy_minor,
        counted_by_user_id, counted_at, version, created_at, updated_at
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, 0, now(), now())`,
      [randomUUID(), command.organizationId, command.branchId, shiftId, method, expected[method], countedAmounts[method], countedAmounts[method] - expected[method], command.actorUserId, closedAt],
    );
  }
  const result = await client.query(
    `UPDATE shifts SET close_operation_id = $4, status = 'closed',
     expected_cash_minor = $5, counted_cash_minor = $6, discrepancy_minor = $7,
     closing_notes = $8, closed_by_user_id = $9, closed_at = $10,
     approved_by_user_id = $11,
     approved_at = CASE WHEN $11::text IS NULL THEN NULL ELSE now() END,
     approval_notes = $12, version = version + 1, updated_at = now()
     WHERE id = $1 AND organization_id = $2 AND branch_id = $3 AND status = 'open'
     RETURNING id, status, version, expected_cash_minor, counted_cash_minor, discrepancy_minor, closed_at`,
    [shiftId, command.organizationId, command.branchId, command.operationId, expected.cash, countedAmounts.cash, discrepancy, optionalString(payload, "notes"), command.actorUserId, closedAt, approvedByUserId, optionalString(payload, "approvalNotes")],
  );
  return {shift: result.rows[0], expectedByPaymentMethod: expected};
}

function requireShiftApproval(
  command: AuthorizedCommand,
  approvedByUserId: string | null,
): void {
  if (approvedByUserId !== command.actorUserId ||
      !command.permissions.has("shifts.discrepancies.approve")) {
    throw new RemoteCommandError(
      "permission-denied",
      "Shift discrepancy approval is required.",
    );
  }
}
