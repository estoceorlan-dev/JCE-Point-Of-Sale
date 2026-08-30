import {randomUUID} from "node:crypto";
import {PoolClient} from "pg";

import {
  AuthorizedCommand,
  CommandResult,
  RemoteCommandError,
  asObject,
  optionalInteger,
  optionalString,
  optionalTimestamp,
  requiredArray,
  requiredBoolean,
  requiredInteger,
  requiredString,
} from "./command_types";

type BalanceRow = {
  id: string;
  on_hand_milli: string;
  version: number;
};

export async function applyInventoryCommand(
  client: PoolClient,
  command: AuthorizedCommand,
): Promise<CommandResult> {
  switch (command.commandType) {
    case "inventory.transaction.post":
      return postInventoryTransaction(client, command);
    case "inventory.transaction.reverse":
      return reverseInventoryTransaction(client, command);
    case "stock_location.create":
      return createStockLocation(client, command);
    case "inventory.reorder_point.set":
      return setReorderPoint(client, command);
    case "inventory.policy.configure":
      return configureInventoryPolicy(client, command);
    default:
      throw new RemoteCommandError(
        "invalid-argument",
        `Unsupported inventory command: ${command.commandType}.`,
      );
  }
}

export async function postInventoryTransaction(
  client: PoolClient,
  command: AuthorizedCommand,
): Promise<CommandResult> {
  const payload = command.payload;
  const transactionId = requiredString(payload, "id");
  const transactionType = requiredString(payload, "transactionType");
  const lines = requiredArray(payload, "lines").map((value, index) => {
    const line = asObject(value, `lines[${index}]`);
    const quantityDeltaMilli = requiredInteger(line, "quantityDeltaMilli");
    if (quantityDeltaMilli === 0) {
      throw new RemoteCommandError("invalid-argument", "Inventory quantities cannot be zero.");
    }
    return {
      stockLocationId: requiredString(line, "stockLocationId"),
      productId: requiredString(line, "productId"),
      quantityDeltaMilli,
      expectedBalanceVersion: optionalInteger(line, "expectedBalanceVersion"),
    };
  });
  if (transactionId !== command.aggregateId || lines.length === 0) {
    throw new RemoteCommandError("invalid-argument", "The inventory transaction is invalid.");
  }
  const lineKeys = lines.map((line) => `${line.stockLocationId}|${line.productId}`);
  if (new Set(lineKeys).size !== lineKeys.length) {
    throw new RemoteCommandError("invalid-argument", "Inventory lines must be unique.");
  }
  const branchResult = await client.query<{allow_negative_stock: boolean; adjustment_approval_threshold_milli: string | null}>(
    `SELECT allow_negative_stock, adjustment_approval_threshold_milli
     FROM branches WHERE id = $1 AND organization_id = $2`,
    [command.branchId, command.organizationId],
  );
  if (branchResult.rowCount !== 1) throw new RemoteCommandError("not-found", "The branch does not exist.");
  const branch = branchResult.rows[0];
  const approvedByUserId = optionalString(payload, "approvedByUserId");
  const threshold = branch.adjustment_approval_threshold_milli === null ?
    null : Number(branch.adjustment_approval_threshold_milli);
  const largestAdjustment = lines.reduce(
    (largest, line) => Math.max(largest, Math.abs(line.quantityDeltaMilli)),
    0,
  );
  const requiresAdjustmentApproval =
    transactionType === "adjustment_increase" ||
    transactionType === "adjustment_decrease";
  if (requiresAdjustmentApproval && threshold !== null && largestAdjustment > threshold) {
    requireSelfApproval(command, approvedByUserId, "inventory.adjustments.approve");
  }

  const occurredAt = optionalTimestamp(payload, "occurredAt") ?? new Date();
  await client.query(
    `
      INSERT INTO inventory_transactions (
        id, organization_id, branch_id, operation_id, transaction_type,
        status, reason_code, notes, reference_type, reference_id,
        reverses_transaction_id, created_by_user_id, approved_by_user_id,
        approved_at, occurred_at, version, created_at, updated_at
      ) VALUES ($1, $2, $3, $4, $5, 'posted', $6, $7, $8, $9, $10, $11, $12,
        CASE WHEN $12::text IS NULL THEN NULL ELSE now() END, $13, 0, now(), now())
    `,
    [
      transactionId,
      command.organizationId,
      command.branchId,
      command.operationId,
      transactionType,
      optionalString(payload, "reasonCode"),
      optionalString(payload, "notes"),
      optionalString(payload, "referenceType"),
      optionalString(payload, "referenceId"),
      optionalString(payload, "reversesTransactionId"),
      command.actorUserId,
      approvedByUserId,
      occurredAt,
    ],
  );

  const balances: Record<string, unknown>[] = [];
  for (const line of lines) {
    const balance = await applyInventoryLine(client, command, line, branch.allow_negative_stock);
    balances.push(balance);
    await client.query(
      `
        INSERT INTO inventory_ledger_entries (
          id, organization_id, branch_id, transaction_id, stock_location_id,
          product_id, quantity_delta_milli, balance_after_milli,
          occurred_at, version, created_at, updated_at
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, 0, now(), now())
      `,
      [
        randomUUID(),
        command.organizationId,
        command.branchId,
        transactionId,
        line.stockLocationId,
        line.productId,
        line.quantityDeltaMilli,
        balance.onHandMilli,
        occurredAt,
      ],
    );
  }
  return {
    inventoryTransaction: {
      id: transactionId,
      transactionType,
      status: "posted",
      occurredAt: occurredAt.toISOString(),
      version: 0,
    },
    lines,
    balances,
  };
}

async function applyInventoryLine(
  client: PoolClient,
  command: AuthorizedCommand,
  line: {
    stockLocationId: string;
    productId: string;
    quantityDeltaMilli: number;
    expectedBalanceVersion: number | null;
  },
  allowNegativeStock: boolean,
): Promise<Record<string, unknown>> {
  await client.query(
    "SELECT pg_advisory_xact_lock(hashtextextended($1, 0))",
    [`${command.organizationId}|${command.branchId}|${line.stockLocationId}|${line.productId}`],
  );
  const scope = await client.query(
    `
      SELECT 1
      FROM stock_locations sl
      INNER JOIN products p
        ON p.id = $4 AND p.organization_id = sl.organization_id
      WHERE sl.id = $3 AND sl.organization_id = $1 AND sl.branch_id = $2 AND sl.deleted_at IS NULL
    `,
    [command.organizationId, command.branchId, line.stockLocationId, line.productId],
  );
  if (scope.rowCount !== 1) {
    throw new RemoteCommandError("invalid-argument", "An inventory line is outside the active scope.");
  }
  let current = await client.query<BalanceRow>(
    `
      SELECT id, on_hand_milli, version FROM inventory_balances
      WHERE organization_id = $1 AND branch_id = $2
        AND stock_location_id = $3 AND product_id = $4
      FOR UPDATE
    `,
    [command.organizationId, command.branchId, line.stockLocationId, line.productId],
  );
  if (current.rowCount === 0) {
    await client.query(
      `
        INSERT INTO inventory_balances (
          id, organization_id, branch_id, stock_location_id, product_id,
          on_hand_milli, reserved_milli, reorder_point_milli,
          version, created_at, updated_at
        ) VALUES ($1, $2, $3, $4, $5, 0, 0, 0, 0, now(), now())
      `,
      [randomUUID(), command.organizationId, command.branchId, line.stockLocationId, line.productId],
    );
    current = await client.query<BalanceRow>(
      `SELECT id, on_hand_milli, version FROM inventory_balances
       WHERE organization_id = $1 AND branch_id = $2 AND stock_location_id = $3 AND product_id = $4
       FOR UPDATE`,
      [command.organizationId, command.branchId, line.stockLocationId, line.productId],
    );
  }
  const balance = current.rows[0];
  if (line.expectedBalanceVersion !== null && balance.version !== line.expectedBalanceVersion) {
    throw new RemoteCommandError("aborted", "The remote inventory balance changed.");
  }
  const nextOnHand = Number(balance.on_hand_milli) + line.quantityDeltaMilli;
  if (!Number.isSafeInteger(nextOnHand) || (!allowNegativeStock && nextOnHand < 0)) {
    throw new RemoteCommandError("failed-precondition", "The movement would create invalid stock.");
  }
  const updated = await client.query<BalanceRow>(
    `
      UPDATE inventory_balances SET
        on_hand_milli = $2, version = version + 1, updated_at = now()
      WHERE id = $1
      RETURNING id, on_hand_milli, version
    `,
    [balance.id, nextOnHand],
  );
  return {
    id: updated.rows[0].id,
    stockLocationId: line.stockLocationId,
    productId: line.productId,
    onHandMilli: Number(updated.rows[0].on_hand_milli),
    version: updated.rows[0].version,
  };
}

async function reverseInventoryTransaction(
  client: PoolClient,
  command: AuthorizedCommand,
): Promise<CommandResult> {
  const originalId = requiredString(command.payload, "reversesTransactionId");
  const reversalId = requiredString(command.payload, "id");
  if (originalId !== command.aggregateId || reversalId === originalId) {
    throw new RemoteCommandError("invalid-argument", "The reversal IDs are invalid.");
  }
  const original = await client.query<{transaction_type: string}>(
    `SELECT transaction_type FROM inventory_transactions
     WHERE id = $1 AND organization_id = $2 AND branch_id = $3 AND status = 'posted'
     FOR UPDATE`,
    [originalId, command.organizationId, command.branchId],
  );
  if (original.rowCount !== 1 || original.rows[0].transaction_type === "reversal") {
    throw new RemoteCommandError("failed-precondition", "The movement cannot be reversed.");
  }
  const existing = await client.query(
    `SELECT id FROM inventory_transactions
     WHERE organization_id = $1 AND branch_id = $2
       AND reverses_transaction_id = $3 AND status = 'posted'`,
    [command.organizationId, command.branchId, originalId],
  );
  if (existing.rowCount !== 0) {
    throw new RemoteCommandError("failed-precondition", "The movement was already reversed.");
  }
  const ledger = await client.query<{
    stock_location_id: string;
    product_id: string;
    quantity_delta_milli: string;
  }>(
    `SELECT stock_location_id, product_id, quantity_delta_milli
     FROM inventory_ledger_entries
     WHERE transaction_id = $1 AND organization_id = $2 AND branch_id = $3
     ORDER BY id`,
    [originalId, command.organizationId, command.branchId],
  );
  if (ledger.rowCount === 0) {
    throw new RemoteCommandError("failed-precondition", "The movement has no ledger entries.");
  }
  const result = await postInventoryTransaction(client, {
    ...command,
    commandType: "inventory.transaction.post",
    aggregateId: reversalId,
    payload: {
      id: reversalId,
      transactionType: "reversal",
      reasonCode: "REVERSAL",
      notes: optionalString(command.payload, "notes"),
      referenceType: "inventory_transaction",
      referenceId: originalId,
      reversesTransactionId: originalId,
      occurredAt: optionalString(command.payload, "occurredAt"),
      lines: ledger.rows.map((line) => ({
        stockLocationId: line.stock_location_id,
        productId: line.product_id,
        quantityDeltaMilli: -Number(line.quantity_delta_milli),
      })),
    },
  });
  await client.query(
    `UPDATE inventory_transactions
     SET status = 'reversed', version = version + 1, updated_at = now()
     WHERE id = $1 AND organization_id = $2 AND branch_id = $3`,
    [originalId, command.organizationId, command.branchId],
  );
  return {...result, reversedTransactionId: originalId};
}

async function createStockLocation(
  client: PoolClient,
  command: AuthorizedCommand,
): Promise<CommandResult> {
  const payload = command.payload;
  const id = requiredString(payload, "id");
  if (id !== command.aggregateId) throw new RemoteCommandError("invalid-argument", "Location IDs do not match.");
  const isDefault = requiredBoolean(payload, "isDefault");
  if (isDefault) {
    await client.query(
      `UPDATE stock_locations SET is_default = false, version = version + 1, updated_at = now()
       WHERE organization_id = $1 AND branch_id = $2 AND is_default = true`,
      [command.organizationId, command.branchId],
    );
  }
  const result = await client.query(
    `
      INSERT INTO stock_locations (
        id, organization_id, branch_id, code, name, location_type,
        is_default, is_active, version, created_at, updated_at
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, true, 0, now(), now())
      RETURNING id, code, name, location_type, is_default, version
    `,
    [id, command.organizationId, command.branchId, requiredString(payload, "code"), requiredString(payload, "name"), requiredString(payload, "locationType"), isDefault],
  );
  return {stockLocation: result.rows[0]};
}

async function setReorderPoint(
  client: PoolClient,
  command: AuthorizedCommand,
): Promise<CommandResult> {
  const payload = command.payload;
  const reorderPointMilli = requiredInteger(payload, "reorderPointMilli");
  const expectedVersion = requiredInteger(payload, "expectedVersion");
  if (reorderPointMilli < 0) throw new RemoteCommandError("invalid-argument", "Reorder point cannot be negative.");
  const stockLocationId = requiredString(payload, "stockLocationId");
  const productId = requiredString(payload, "productId");
  if (expectedVersion < 0) throw new RemoteCommandError("invalid-argument", "The expected version is invalid.");
  await client.query(
    "SELECT pg_advisory_xact_lock(hashtextextended($1, 0))",
    [`${command.organizationId}|${command.branchId}|${stockLocationId}|${productId}`],
  );
  const scope = await client.query(
    `SELECT 1 FROM stock_locations sl
     INNER JOIN products p ON p.id = $4 AND p.organization_id = sl.organization_id
       AND p.is_active = true AND p.deleted_at IS NULL
     WHERE sl.id = $3 AND sl.organization_id = $1 AND sl.branch_id = $2
       AND sl.is_active = true AND sl.deleted_at IS NULL`,
    [command.organizationId, command.branchId, stockLocationId, productId],
  );
  if (scope.rowCount !== 1) {
    throw new RemoteCommandError("not-found", "The stock location or product does not exist.");
  }
  if (expectedVersion === 0) {
    const inserted = await client.query(
      `INSERT INTO inventory_balances (
         id, organization_id, branch_id, stock_location_id, product_id,
         on_hand_milli, reserved_milli, reorder_point_milli,
         version, created_at, updated_at
       ) VALUES ($1, $2, $3, $4, $5, 0, 0, $6, 1, now(), now())
       ON CONFLICT (organization_id, branch_id, stock_location_id, product_id) DO NOTHING
       RETURNING id, on_hand_milli, reorder_point_milli, version`,
      [randomUUID(), command.organizationId, command.branchId, stockLocationId, productId, reorderPointMilli],
    );
    if (inserted.rowCount === 1) return {balance: inserted.rows[0]};
  }
  const result = await client.query(
    `
      UPDATE inventory_balances SET reorder_point_milli = $5, version = version + 1, updated_at = now()
      WHERE organization_id = $1 AND branch_id = $2 AND stock_location_id = $3 AND product_id = $4
        AND version = $6
      RETURNING id, on_hand_milli, reorder_point_milli, version
    `,
    [command.organizationId, command.branchId, stockLocationId, productId, reorderPointMilli, expectedVersion],
  );
  if (result.rowCount !== 1) throw new RemoteCommandError("aborted", "The remote inventory balance changed.");
  return {balance: result.rows[0]};
}

async function configureInventoryPolicy(
  client: PoolClient,
  command: AuthorizedCommand,
): Promise<CommandResult> {
  const allowNegativeStock = requiredBoolean(command.payload, "allowNegativeStock");
  const threshold = optionalInteger(command.payload, "adjustmentApprovalThresholdMilli");
  if (threshold !== null && threshold < 0) throw new RemoteCommandError("invalid-argument", "The approval threshold is invalid.");
  const result = await client.query(
    `UPDATE branches SET allow_negative_stock = $3, adjustment_approval_threshold_milli = $4,
     version = version + 1, updated_at = now()
     WHERE id = $1 AND organization_id = $2 RETURNING id, version`,
    [command.branchId, command.organizationId, allowNegativeStock, threshold],
  );
  return {branch: result.rows[0]};
}

function requireSelfApproval(
  command: AuthorizedCommand,
  approvedByUserId: string | null,
  permission: string,
): void {
  if (approvedByUserId !== command.actorUserId || !command.permissions.has(permission)) {
    throw new RemoteCommandError("permission-denied", `The ${permission} permission is required.`);
  }
}
