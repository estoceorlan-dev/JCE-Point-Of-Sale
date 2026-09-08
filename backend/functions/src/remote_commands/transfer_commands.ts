import {randomUUID} from "node:crypto";
import {PoolClient} from "pg";

import {
  AuthorizedCommand,
  CommandResult,
  RemoteCommandError,
  asObject,
  optionalString,
  optionalTimestamp,
  requiredArray,
  requiredInteger,
  requiredString,
} from "./command_types";
import {postInventoryTransaction} from "./inventory_commands";

type TransferRow = {
  id: string;
  source_branch_id: string;
  destination_branch_id: string;
  transfer_number: string;
  status: string;
  approval_required: boolean;
  version: number;
};

type ItemRow = {
  id: string;
  product_id: string;
  source_stock_location_id: string;
  destination_stock_location_id: string;
  damaged_stock_location_id: string | null;
  requested_quantity_milli: string;
  shipped_quantity_milli: string;
  received_quantity_milli: string;
  damaged_quantity_milli: string;
  discrepancy_quantity_milli: string;
  version: number;
};

type QuantityLine = {
  transferItemId: string;
  receivedQuantityMilli: number;
  damagedQuantityMilli: number;
  damagedStockLocationId: string | null;
};

export async function applyTransferCommand(
  client: PoolClient,
  command: AuthorizedCommand,
): Promise<CommandResult> {
  switch (command.commandType) {
    case "transfer.create":
      return createTransfer(client, command);
    case "transfer.submit":
      return submitTransfer(client, command);
    case "transfer.approve":
      return approveTransfer(client, command);
    case "transfer.reject":
      return rejectTransfer(client, command);
    case "transfer.ship":
      return shipTransfer(client, command);
    case "transfer.receive":
      return receiveTransfer(client, command);
    case "transfer.correct_receipt":
      return correctReceipt(client, command);
    case "transfer.cancel":
      return cancelTransfer(client, command);
    default:
      throw new RemoteCommandError(
        "invalid-argument",
        `Unsupported transfer command: ${command.commandType}.`,
      );
  }
}

async function createTransfer(
  client: PoolClient,
  command: AuthorizedCommand,
): Promise<CommandResult> {
  const payload = command.payload;
  const transferId = requiredString(payload, "id");
  const sourceBranchId = requiredString(payload, "sourceBranchId");
  const destinationBranchId = requiredString(payload, "destinationBranchId");
  if (transferId !== command.aggregateId || sourceBranchId !== command.branchId ||
      sourceBranchId === destinationBranchId) {
    throw new RemoteCommandError(
      "invalid-argument",
      "Transfer branch identifiers are invalid.",
    );
  }
  const destination = await client.query(
    `SELECT 1 FROM branches
     WHERE id = $1 AND organization_id = $2
       AND is_active = true AND deleted_at IS NULL FOR SHARE`,
    [destinationBranchId, command.organizationId],
  );
  if (destination.rowCount !== 1) {
    throw new RemoteCommandError("not-found", "The destination branch does not exist.");
  }
  const branch = await client.query<{
    transfer_approval_threshold_milli: string | null;
  }>(
    `SELECT transfer_approval_threshold_milli FROM branches
     WHERE id = $1 AND organization_id = $2
       AND is_active = true AND deleted_at IS NULL`,
    [sourceBranchId, command.organizationId],
  );
  if (branch.rowCount !== 1) {
    throw new RemoteCommandError("not-found", "The source branch does not exist.");
  }
  const rawLines = requiredArray(payload, "lines");
  if (rawLines.length === 0) {
    throw new RemoteCommandError("invalid-argument", "A transfer requires an item.");
  }
  const lines = [] as Array<{
    id: string;
    productId: string;
    sourceStockLocationId: string;
    destinationStockLocationId: string;
    quantityMilli: number;
  }>;
  const keys = new Set<string>();
  let totalQuantity = 0;
  for (let index = 0; index < rawLines.length; index += 1) {
    const input = asObject(rawLines[index], `lines[${index}]`);
    const line = {
      id: requiredString(input, "id"),
      productId: requiredString(input, "productId"),
      sourceStockLocationId: requiredString(input, "sourceStockLocationId"),
      destinationStockLocationId: requiredString(
        input,
        "destinationStockLocationId",
      ),
      quantityMilli: requiredInteger(input, "quantityMilli"),
    };
    const key = `${line.sourceStockLocationId}|${line.productId}`;
    if (line.quantityMilli <= 0 || !keys.add(key)) {
      throw new RemoteCommandError("invalid-argument", "A transfer line is invalid.");
    }
    await validateLineScope(
      client,
      command,
      sourceBranchId,
      destinationBranchId,
      line,
    );
    totalQuantity += line.quantityMilli;
    lines.push(line);
  }
  const threshold = branch.rows[0].transfer_approval_threshold_milli;
  const approvalRequired = threshold !== null && totalQuantity > Number(threshold);
  const occurredAt = optionalTimestamp(payload, "createdAt") ?? new Date();
  await client.query(
    `INSERT INTO stock_transfers (
       id, organization_id, source_branch_id, destination_branch_id,
       transfer_number, status, approval_required, notes, created_by_user_id,
       version, created_at, updated_at
     ) VALUES ($1, $2, $3, $4, $5, 'draft', $6, $7, $8, 0, $9, $9)`,
    [
      transferId,
      command.organizationId,
      sourceBranchId,
      destinationBranchId,
      requiredString(payload, "transferNumber"),
      approvalRequired,
      optionalString(payload, "notes"),
      command.actorUserId,
      occurredAt,
    ],
  );
  for (const line of lines) {
    await client.query(
      `INSERT INTO stock_transfer_items (
         id, organization_id, transfer_id, product_id,
         source_stock_location_id, destination_stock_location_id,
         requested_quantity_milli, version, created_at, updated_at
       ) VALUES ($1, $2, $3, $4, $5, $6, $7, 0, $8, $8)`,
      [
        line.id,
        command.organizationId,
        transferId,
        line.productId,
        line.sourceStockLocationId,
        line.destinationStockLocationId,
        line.quantityMilli,
        occurredAt,
      ],
    );
  }
  const event = await insertEvent(
    client,
    command,
    transferId,
    "created",
    null,
    "draft",
    occurredAt,
  );
  return transferResult(client, command.organizationId, transferId, event);
}

async function submitTransfer(
  client: PoolClient,
  command: AuthorizedCommand,
): Promise<CommandResult> {
  const transfer = await requireTransfer(client, command, "source");
  requireState(transfer, "draft", command.payload);
  const occurredAt = eventTime(command);
  const next = transfer.approval_required ? "submitted" : "approved";
  let balances: Record<string, unknown>[] = [];
  if (next === "approved") {
    balances = await reserveStock(client, command, transfer, true);
  }
  await updateTransfer(client, transfer, next, occurredAt, {
    submitted: true,
    approved: next === "approved",
    approvedBy: next === "approved" ? command.actorUserId : null,
  });
  const event = await insertEvent(
    client,
    command,
    transfer.id,
    next === "approved" ? "auto_approved" : "submitted",
    "draft",
    next,
    occurredAt,
  );
  return {
    ...(await transferResult(client, command.organizationId, transfer.id, event)),
    balances,
  };
}

async function approveTransfer(
  client: PoolClient,
  command: AuthorizedCommand,
): Promise<CommandResult> {
  const transfer = await requireTransfer(client, command, "source");
  requireState(transfer, "submitted", command.payload);
  await requireDestinationApproval(client, command, transfer.destination_branch_id);
  const balances = await reserveStock(client, command, transfer, true);
  const occurredAt = eventTime(command);
  await updateTransfer(client, transfer, "approved", occurredAt, {
    approved: true,
    approvedBy: command.actorUserId,
  });
  const event = await insertEvent(
    client,
    command,
    transfer.id,
    "approved",
    "submitted",
    "approved",
    occurredAt,
  );
  return {
    ...(await transferResult(client, command.organizationId, transfer.id, event)),
    balances,
  };
}

async function rejectTransfer(
  client: PoolClient,
  command: AuthorizedCommand,
): Promise<CommandResult> {
  const transfer = await requireTransfer(client, command, "source");
  requireState(transfer, "submitted", command.payload);
  await requireDestinationApproval(client, command, transfer.destination_branch_id);
  const reason = requiredString(command.payload, "reason");
  const occurredAt = eventTime(command);
  await updateTransfer(client, transfer, "rejected", occurredAt, {reason});
  const event = await insertEvent(
    client,
    command,
    transfer.id,
    "rejected",
    "submitted",
    "rejected",
    occurredAt,
    reason,
  );
  return transferResult(client, command.organizationId, transfer.id, event);
}

async function shipTransfer(
  client: PoolClient,
  command: AuthorizedCommand,
): Promise<CommandResult> {
  const transfer = await requireTransfer(client, command, "source");
  requireState(transfer, "approved", command.payload);
  const balances = await reserveStock(client, command, transfer, false);
  const items = await loadItems(client, command.organizationId, transfer.id);
  const inventoryTransactionId = requiredString(
    command.payload,
    "inventoryTransactionId",
  );
  const occurredAt = eventTime(command);
  const inventory = await postInventoryTransaction(client, {
    ...command,
    operationId: `${command.operationId}:inventory`,
    commandType: "inventory.transaction.post",
    aggregateType: "inventory_transaction",
    aggregateId: inventoryTransactionId,
    payload: {
      id: inventoryTransactionId,
      transactionType: "transfer_shipment",
      referenceType: "stock_transfer",
      referenceId: transfer.id,
      occurredAt: occurredAt.toISOString(),
      lines: items.map((item) => ({
        stockLocationId: item.source_stock_location_id,
        productId: item.product_id,
        quantityDeltaMilli: -Number(item.requested_quantity_milli),
      })),
    },
  });
  await client.query(
    `UPDATE stock_transfer_items SET
       shipped_quantity_milli = requested_quantity_milli,
       discrepancy_quantity_milli = requested_quantity_milli,
       version = version + 1, updated_at = $2
     WHERE transfer_id = $1`,
    [transfer.id, occurredAt],
  );
  await updateTransfer(client, transfer, "shipped", occurredAt, {shipped: true});
  const event = await insertEvent(
    client,
    command,
    transfer.id,
    "shipped",
    "approved",
    "shipped",
    occurredAt,
    null,
    {inventoryTransactionId},
  );
  return {
    ...(await transferResult(client, command.organizationId, transfer.id, event)),
    reservationBalances: balances,
    inventory,
  };
}

async function receiveTransfer(
  client: PoolClient,
  command: AuthorizedCommand,
): Promise<CommandResult> {
  const transfer = await requireTransfer(client, command, "destination");
  requireState(transfer, "shipped", command.payload);
  const items = await loadItems(client, command.organizationId, transfer.id);
  const lines = parseQuantityLines(command.payload, items);
  const inventoryLines = await receiptInventoryLines(
    client,
    command,
    items,
    lines,
    false,
  );
  const inventoryTransactionId = requiredString(
    command.payload,
    "inventoryTransactionId",
  );
  const occurredAt = eventTime(command);
  const inventory = inventoryLines.length === 0 ? null :
    await postInventoryTransaction(client, {
      ...command,
      operationId: `${command.operationId}:inventory`,
      commandType: "inventory.transaction.post",
      aggregateType: "inventory_transaction",
      aggregateId: inventoryTransactionId,
      payload: {
        id: inventoryTransactionId,
        transactionType: "transfer_receipt",
        notes: optionalString(command.payload, "notes"),
        referenceType: "stock_transfer",
        referenceId: transfer.id,
        occurredAt: occurredAt.toISOString(),
        lines: inventoryLines,
      },
    });
  await saveReceiptLines(client, items, lines, occurredAt);
  await updateTransfer(client, transfer, "received", occurredAt, {received: true});
  const event = await insertEvent(
    client,
    command,
    transfer.id,
    "received",
    "shipped",
    "received",
    occurredAt,
    null,
    {inventoryTransactionId: inventory === null ? null : inventoryTransactionId},
  );
  return {
    ...(await transferResult(client, command.organizationId, transfer.id, event)),
    inventory,
  };
}

async function correctReceipt(
  client: PoolClient,
  command: AuthorizedCommand,
): Promise<CommandResult> {
  const transfer = await requireTransfer(client, command, "destination");
  requireState(transfer, "received", command.payload);
  const reason = requiredString(command.payload, "reason");
  const approvedBy = requiredString(command.payload, "approvedByUserId");
  if (approvedBy !== command.actorUserId) {
    throw new RemoteCommandError("permission-denied", "Self approval is required.");
  }
  const items = await loadItems(client, command.organizationId, transfer.id);
  const lines = parseQuantityLines(command.payload, items);
  const inventoryLines = await receiptInventoryLines(
    client,
    command,
    items,
    lines,
    true,
  );
  if (inventoryLines.length === 0) {
    throw new RemoteCommandError("invalid-argument", "The correction changes no stock.");
  }
  const inventoryTransactionId = requiredString(
    command.payload,
    "inventoryTransactionId",
  );
  const occurredAt = eventTime(command);
  const inventory = await postInventoryTransaction(client, {
    ...command,
    operationId: `${command.operationId}:inventory`,
    commandType: "inventory.transaction.post",
    aggregateType: "inventory_transaction",
    aggregateId: inventoryTransactionId,
    payload: {
      id: inventoryTransactionId,
      transactionType: "reversal",
      reasonCode: "TRANSFER_CORRECTION",
      notes: optionalString(command.payload, "notes") ?? reason,
      referenceType: "stock_transfer_correction",
      referenceId: transfer.id,
      approvedByUserId: approvedBy,
      occurredAt: occurredAt.toISOString(),
      lines: inventoryLines,
    },
  });
  await saveReceiptLines(client, items, lines, occurredAt);
  await client.query(
    `UPDATE stock_transfers SET version = version + 1, updated_at = $2
     WHERE id = $1`,
    [transfer.id, occurredAt],
  );
  const event = await insertEvent(
    client,
    command,
    transfer.id,
    "receipt_corrected",
    "received",
    "received",
    occurredAt,
    reason,
    {approvedByUserId: approvedBy, inventoryTransactionId},
  );
  return {
    ...(await transferResult(client, command.organizationId, transfer.id, event)),
    inventory,
  };
}

async function cancelTransfer(
  client: PoolClient,
  command: AuthorizedCommand,
): Promise<CommandResult> {
  const transfer = await requireTransfer(client, command, "source");
  const expectedVersion = requiredInteger(command.payload, "expectedVersion");
  if (!["draft", "submitted", "approved"].includes(transfer.status) ||
      transfer.version !== expectedVersion) {
    throw new RemoteCommandError(
      "failed-precondition",
      "The transfer can no longer be cancelled.",
    );
  }
  const balances = transfer.status === "approved" ?
    await reserveStock(client, command, transfer, false) : [];
  const reason = requiredString(command.payload, "reason");
  const occurredAt = eventTime(command);
  const from = transfer.status;
  await updateTransfer(client, transfer, "cancelled", occurredAt, {
    cancelled: true,
    reason,
  });
  const event = await insertEvent(
    client,
    command,
    transfer.id,
    "cancelled",
    from,
    "cancelled",
    occurredAt,
    reason,
  );
  return {
    ...(await transferResult(client, command.organizationId, transfer.id, event)),
    balances,
  };
}

async function requireTransfer(
  client: PoolClient,
  command: AuthorizedCommand,
  scope: "source" | "destination",
): Promise<TransferRow> {
  if (requiredString(command.payload, "id") !== command.aggregateId) {
    throw new RemoteCommandError("invalid-argument", "Transfer IDs do not match.");
  }
  const result = await client.query<TransferRow>(
    `SELECT id, source_branch_id, destination_branch_id, transfer_number,
            status, approval_required, version
     FROM stock_transfers
     WHERE id = $1 AND organization_id = $2
     FOR UPDATE`,
    [command.aggregateId, command.organizationId],
  );
  const transfer = result.rows[0];
  const scopedBranch = scope === "source" ?
    transfer?.source_branch_id : transfer?.destination_branch_id;
  if (result.rowCount !== 1 || scopedBranch !== command.branchId) {
    throw new RemoteCommandError(
      "permission-denied",
      "The transfer is outside the active branch scope.",
    );
  }
  return transfer;
}

function requireState(
  transfer: TransferRow,
  status: string,
  payload: Record<string, unknown>,
): void {
  if (transfer.status !== status ||
      transfer.version !== requiredInteger(payload, "expectedVersion")) {
    throw new RemoteCommandError(
      "failed-precondition",
      "The transfer state or version changed.",
    );
  }
}

async function loadItems(
  client: PoolClient,
  organizationId: string,
  transferId: string,
): Promise<ItemRow[]> {
  const result = await client.query<ItemRow>(
    `SELECT id, product_id, source_stock_location_id,
            destination_stock_location_id, damaged_stock_location_id,
            requested_quantity_milli, shipped_quantity_milli,
            received_quantity_milli, damaged_quantity_milli,
            discrepancy_quantity_milli, version
     FROM stock_transfer_items
     WHERE transfer_id = $1 AND organization_id = $2
     ORDER BY id
     FOR UPDATE`,
    [transferId, organizationId],
  );
  if (result.rowCount === 0) {
    throw new RemoteCommandError("failed-precondition", "The transfer has no items.");
  }
  return result.rows;
}

async function reserveStock(
  client: PoolClient,
  command: AuthorizedCommand,
  transfer: TransferRow,
  reserve: boolean,
): Promise<Record<string, unknown>[]> {
  const policy = await client.query<{allow_negative_stock: boolean}>(
    `SELECT allow_negative_stock FROM branches
     WHERE id = $1 AND organization_id = $2`,
    [transfer.source_branch_id, command.organizationId],
  );
  const items = await loadItems(client, command.organizationId, transfer.id);
  const balances: Record<string, unknown>[] = [];
  for (const item of items) {
    const result = await client.query<{
      id: string;
      on_hand_milli: string;
      reserved_milli: string;
      version: number;
    }>(
      `SELECT id, on_hand_milli, reserved_milli, version
       FROM inventory_balances
       WHERE organization_id = $1 AND branch_id = $2
         AND stock_location_id = $3 AND product_id = $4
       FOR UPDATE`,
      [
        command.organizationId,
        transfer.source_branch_id,
        item.source_stock_location_id,
        item.product_id,
      ],
    );
    if (result.rowCount !== 1) {
      throw new RemoteCommandError(
        "failed-precondition",
        "Source stock is unavailable for a transfer item.",
      );
    }
    const balance = result.rows[0];
    const requested = Number(item.requested_quantity_milli);
    const nextReserved = Number(balance.reserved_milli) + (reserve ? requested : -requested);
    if (nextReserved < 0 ||
        reserve && !policy.rows[0].allow_negative_stock &&
        Number(balance.on_hand_milli) < nextReserved) {
      throw new RemoteCommandError(
        "failed-precondition",
        "Available source stock is insufficient.",
      );
    }
    const updated = await client.query<{version: number}>(
      `UPDATE inventory_balances SET reserved_milli = $2,
         version = version + 1, updated_at = now()
       WHERE id = $1 RETURNING version`,
      [balance.id, nextReserved],
    );
    balances.push({
      id: balance.id,
      stockLocationId: item.source_stock_location_id,
      productId: item.product_id,
      onHandMilli: Number(balance.on_hand_milli),
      reservedMilli: nextReserved,
      version: updated.rows[0].version,
    });
  }
  return balances;
}

function parseQuantityLines(
  payload: Record<string, unknown>,
  items: ItemRow[],
): QuantityLine[] {
  const raw = requiredArray(payload, "lines");
  const byId = new Map(items.map((item) => [item.id, item]));
  const seen = new Set<string>();
  const lines = raw.map((value, index) => {
    const input = asObject(value, `lines[${index}]`);
    const transferItemId = requiredString(input, "transferItemId");
    const item = byId.get(transferItemId);
    const received = requiredInteger(input, "receivedQuantityMilli");
    const damaged = requiredInteger(input, "damagedQuantityMilli");
    const damagedLocation = optionalString(input, "damagedStockLocationId");
    if (item === undefined || !seen.add(transferItemId) || received < 0 ||
        damaged < 0 || received + damaged > Number(item.shipped_quantity_milli) ||
        (damaged > 0) !== (damagedLocation !== null)) {
      throw new RemoteCommandError(
        "invalid-argument",
        "Transfer receipt quantities are invalid.",
      );
    }
    return {
      transferItemId,
      receivedQuantityMilli: received,
      damagedQuantityMilli: damaged,
      damagedStockLocationId: damagedLocation,
    };
  });
  if (lines.length !== items.length) {
    throw new RemoteCommandError(
      "invalid-argument",
      "Every transfer item must be reconciled once.",
    );
  }
  return lines;
}

async function receiptInventoryLines(
  client: PoolClient,
  command: AuthorizedCommand,
  items: ItemRow[],
  lines: QuantityLine[],
  correction: boolean,
): Promise<Array<{
  stockLocationId: string;
  productId: string;
  quantityDeltaMilli: number;
}>> {
  const byItem = new Map(lines.map((line) => [line.transferItemId, line]));
  const totals = new Map<string, {
    stockLocationId: string;
    productId: string;
    quantityDeltaMilli: number;
  }>();
  for (const item of items) {
    const line = byItem.get(item.id)!;
    await validateDestinationLocation(
      client,
      command,
      item.destination_stock_location_id,
      false,
    );
    addQuantity(
      totals,
      item.destination_stock_location_id,
      item.product_id,
      line.receivedQuantityMilli -
        (correction ? Number(item.received_quantity_milli) : 0),
    );
    if (correction && Number(item.damaged_quantity_milli) > 0) {
      addQuantity(
        totals,
        item.damaged_stock_location_id!,
        item.product_id,
        -Number(item.damaged_quantity_milli),
      );
    }
    if (line.damagedQuantityMilli > 0) {
      await validateDestinationLocation(
        client,
        command,
        line.damagedStockLocationId!,
        true,
      );
      addQuantity(
        totals,
        line.damagedStockLocationId!,
        item.product_id,
        line.damagedQuantityMilli,
      );
    }
  }
  return [...totals.values()].filter((line) => line.quantityDeltaMilli !== 0);
}

function addQuantity(
  totals: Map<string, {
    stockLocationId: string;
    productId: string;
    quantityDeltaMilli: number;
  }>,
  stockLocationId: string,
  productId: string,
  quantity: number,
): void {
  const key = `${stockLocationId}|${productId}`;
  const existing = totals.get(key);
  totals.set(key, {
    stockLocationId,
    productId,
    quantityDeltaMilli: (existing?.quantityDeltaMilli ?? 0) + quantity,
  });
}

async function saveReceiptLines(
  client: PoolClient,
  items: ItemRow[],
  lines: QuantityLine[],
  occurredAt: Date,
): Promise<void> {
  const byItem = new Map(lines.map((line) => [line.transferItemId, line]));
  for (const item of items) {
    const line = byItem.get(item.id)!;
    const discrepancy = Number(item.shipped_quantity_milli) -
      line.receivedQuantityMilli - line.damagedQuantityMilli;
    await client.query(
      `UPDATE stock_transfer_items SET
         received_quantity_milli = $2,
         damaged_quantity_milli = $3,
         damaged_stock_location_id = $4,
         discrepancy_quantity_milli = $5,
         version = version + 1,
         updated_at = $6
       WHERE id = $1`,
      [
        item.id,
        line.receivedQuantityMilli,
        line.damagedQuantityMilli,
        line.damagedStockLocationId,
        discrepancy,
        occurredAt,
      ],
    );
  }
}

async function validateLineScope(
  client: PoolClient,
  command: AuthorizedCommand,
  sourceBranchId: string,
  destinationBranchId: string,
  line: {
    productId: string;
    sourceStockLocationId: string;
    destinationStockLocationId: string;
  },
): Promise<void> {
  const result = await client.query(
    `SELECT 1
     FROM products p
     INNER JOIN stock_locations source
       ON source.id = $3 AND source.organization_id = p.organization_id
      AND source.branch_id = $5 AND source.is_active = true
      AND source.deleted_at IS NULL
     INNER JOIN stock_locations destination
       ON destination.id = $4
      AND destination.organization_id = p.organization_id
      AND destination.branch_id = $6 AND destination.is_active = true
      AND destination.deleted_at IS NULL
     WHERE p.id = $1 AND p.organization_id = $2
       AND p.is_active = true AND p.deleted_at IS NULL FOR SHARE OF source, destination`,
    [
      line.productId,
      command.organizationId,
      line.sourceStockLocationId,
      line.destinationStockLocationId,
      sourceBranchId,
      destinationBranchId,
    ],
  );
  if (result.rowCount !== 1) {
    throw new RemoteCommandError(
      "invalid-argument",
      "A transfer line is outside the branch scope.",
    );
  }
}

async function validateDestinationLocation(
  client: PoolClient,
  command: AuthorizedCommand,
  locationId: string,
  damaged: boolean,
): Promise<void> {
  const result = await client.query<{location_type: string}>(
    `SELECT location_type FROM stock_locations
     WHERE id = $1 AND organization_id = $2 AND branch_id = $3
       AND is_active = true AND deleted_at IS NULL FOR SHARE`,
    [locationId, command.organizationId, command.branchId],
  );
  if (result.rowCount !== 1 || damaged && result.rows[0].location_type !== "damaged") {
    throw new RemoteCommandError(
      "invalid-argument",
      damaged ? "A damaged location is required." : "The destination is invalid.",
    );
  }
}

async function requireDestinationApproval(
  client: PoolClient,
  command: AuthorizedCommand,
  destinationBranchId: string,
): Promise<void> {
  const result = await client.query(
    `SELECT 1
     FROM user_role_assignments ura
     INNER JOIN roles r ON r.id = ura.role_id
       AND r.organization_id = ura.organization_id
       AND r.is_active = true AND r.deleted_at IS NULL
     INNER JOIN role_permissions rp ON rp.role_id = r.id
       AND rp.permission_code = 'transfers.approve'
     WHERE ura.user_id = $1 AND ura.organization_id = $2
       AND (ura.branch_id IS NULL OR ura.branch_id = $3)
       AND ura.revoked_at IS NULL
     LIMIT 1`,
    [command.actorUserId, command.organizationId, destinationBranchId],
  );
  if (result.rowCount !== 1) {
    throw new RemoteCommandError(
      "permission-denied",
      "Transfer approval requires assignment to both branches.",
    );
  }
}

async function updateTransfer(
  client: PoolClient,
  transfer: TransferRow,
  status: string,
  occurredAt: Date,
  options: {
    submitted?: boolean;
    approved?: boolean;
    approvedBy?: string | null;
    shipped?: boolean;
    received?: boolean;
    cancelled?: boolean;
    reason?: string;
  },
): Promise<void> {
  const result = await client.query(
    `UPDATE stock_transfers SET
       status = $2,
       submitted_at = CASE WHEN $3 THEN $9 ELSE submitted_at END,
       approved_at = CASE WHEN $4 THEN $9 ELSE approved_at END,
       approved_by_user_id = COALESCE($5, approved_by_user_id),
       shipped_at = CASE WHEN $6 THEN $9 ELSE shipped_at END,
       received_at = CASE WHEN $7 THEN $9 ELSE received_at END,
       cancelled_at = CASE WHEN $8 THEN $9 ELSE cancelled_at END,
       rejection_reason = CASE WHEN $2 = 'rejected' THEN $10 ELSE rejection_reason END,
       cancellation_reason = CASE WHEN $2 = 'cancelled' THEN $10 ELSE cancellation_reason END,
       version = version + 1,
       updated_at = $9
     WHERE id = $1 AND version = $11`,
    [
      transfer.id,
      status,
      options.submitted === true,
      options.approved === true,
      options.approvedBy ?? null,
      options.shipped === true,
      options.received === true,
      options.cancelled === true,
      occurredAt,
      options.reason ?? null,
      transfer.version,
    ],
  );
  if (result.rowCount !== 1) {
    throw new RemoteCommandError("aborted", "The transfer changed concurrently.");
  }
}

async function insertEvent(
  client: PoolClient,
  command: AuthorizedCommand,
  transferId: string,
  eventType: string,
  fromStatus: string | null,
  toStatus: string,
  occurredAt: Date,
  reason: string | null = null,
  metadata: Record<string, unknown> = {},
): Promise<Record<string, unknown>> {
  const id = randomUUID();
  await client.query(
    `INSERT INTO transfer_events (
       id, organization_id, transfer_id, operation_id, event_type,
       from_status, to_status, actor_user_id, reason, metadata_json,
       occurred_at, created_at
     ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, now())`,
    [
      id,
      command.organizationId,
      transferId,
      command.operationId,
      eventType,
      fromStatus,
      toStatus,
      command.actorUserId,
      reason,
      metadata,
      occurredAt,
    ],
  );
  return {
    id,
    operationId: command.operationId,
    eventType,
    fromStatus,
    toStatus,
    actorUserId: command.actorUserId,
    reason,
    metadata,
    occurredAt: occurredAt.toISOString(),
  };
}

async function transferResult(
  client: PoolClient,
  organizationId: string,
  transferId: string,
  event: Record<string, unknown>,
): Promise<CommandResult> {
  const transfer = await client.query(
    `SELECT id, source_branch_id AS "sourceBranchId",
            destination_branch_id AS "destinationBranchId",
            transfer_number AS "transferNumber", status,
            approval_required AS "approvalRequired", notes,
            created_by_user_id AS "createdByUserId",
            approved_by_user_id AS "approvedByUserId",
            rejection_reason AS "rejectionReason",
            cancellation_reason AS "cancellationReason",
            submitted_at AS "submittedAt", approved_at AS "approvedAt",
            shipped_at AS "shippedAt", received_at AS "receivedAt",
            cancelled_at AS "cancelledAt", version, created_at AS "createdAt",
            updated_at AS "updatedAt"
     FROM stock_transfers WHERE id = $1 AND organization_id = $2`,
    [transferId, organizationId],
  );
  const items = await client.query(
    `SELECT id, product_id AS "productId",
            source_stock_location_id AS "sourceStockLocationId",
            destination_stock_location_id AS "destinationStockLocationId",
            damaged_stock_location_id AS "damagedStockLocationId",
            requested_quantity_milli::bigint AS "requestedQuantityMilli",
            shipped_quantity_milli::bigint AS "shippedQuantityMilli",
            received_quantity_milli::bigint AS "receivedQuantityMilli",
            damaged_quantity_milli::bigint AS "damagedQuantityMilli",
            discrepancy_quantity_milli::bigint AS "discrepancyQuantityMilli",
            version
     FROM stock_transfer_items
     WHERE transfer_id = $1 AND organization_id = $2 ORDER BY id`,
    [transferId, organizationId],
  );
  return {transfer: transfer.rows[0], items: items.rows, event};
}

function eventTime(command: AuthorizedCommand): Date {
  return optionalTimestamp(command.payload, "occurredAt") ?? new Date();
}
