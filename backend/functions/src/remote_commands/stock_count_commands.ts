import {randomUUID} from "node:crypto";
import {PoolClient} from "pg";

import {
  AuthorizedCommand,
  CommandResult,
  RemoteCommandError,
  optionalString,
  optionalTimestamp,
  requiredArray,
  requiredInteger,
  requiredString,
} from "./command_types";
import {postInventoryTransaction} from "./inventory_commands";

export async function applyStockCountCommand(
  client: PoolClient,
  command: AuthorizedCommand,
): Promise<CommandResult> {
  switch (command.commandType) {
    case "stock_count.start":
      return startStockCount(client, command);
    case "stock_count.item.record":
      return recordStockCountItem(client, command);
    case "stock_count.complete":
      return completeStockCount(client, command);
    case "stock_count.cancel":
      return cancelStockCount(client, command);
    default:
      throw new RemoteCommandError(
        "invalid-argument",
        `Unsupported stock count command: ${command.commandType}.`,
      );
  }
}

async function startStockCount(
  client: PoolClient,
  command: AuthorizedCommand,
): Promise<CommandResult> {
  const id = requiredString(command.payload, "id");
  const stockLocationId = requiredString(command.payload, "stockLocationId");
  const countType = requiredString(command.payload, "countType");
  const clientItems = Array.isArray(command.payload.items) ?
    requiredArray(command.payload, "items").map((value, index) => {
      if (typeof value !== "object" || value === null || Array.isArray(value)) {
        throw new RemoteCommandError("invalid-argument", `items[${index}] must be an object.`);
      }
      const item = value as Record<string, unknown>;
      return {id: requiredString(item, "id"), productId: requiredString(item, "productId")};
    }) : null;
  const productIds = (clientItems?.map((item) => item.productId) ??
    requiredArray(command.payload, "productIds")).map((value) => {
    if (typeof value !== "string" || value.trim().length === 0) {
      throw new RemoteCommandError("invalid-argument", "Product IDs must be strings.");
    }
    return value.trim();
  });
  if (id !== command.aggregateId ||
      !["full", "cycle"].includes(countType) ||
      productIds.length === 0 ||
      new Set(productIds).size !== productIds.length) {
    throw new RemoteCommandError("invalid-argument", "The stock count is invalid.");
  }
  await client.query(
    "SELECT pg_advisory_xact_lock(hashtextextended($1, 0))",
    [`${command.organizationId}|${command.branchId}|stock-count|${stockLocationId}`],
  );
  const openCount = await client.query(
    `SELECT 1 FROM stock_counts
     WHERE organization_id = $1 AND branch_id = $2
       AND stock_location_id = $3 AND status = 'in_progress'`,
    [command.organizationId, command.branchId, stockLocationId],
  );
  if (openCount.rowCount !== 0) {
    throw new RemoteCommandError("failed-precondition", "The location already has an open count.");
  }
  const products = await client.query<{
    id: string;
    expected_quantity_milli: string;
  }>(
    `SELECT p.id, COALESCE(ib.on_hand_milli, 0)::text AS expected_quantity_milli
     FROM products p
     INNER JOIN stock_locations sl
       ON sl.id = $3 AND sl.organization_id = p.organization_id
       AND sl.branch_id = $2 AND sl.is_active = true AND sl.deleted_at IS NULL
     LEFT JOIN inventory_balances ib
       ON ib.organization_id = p.organization_id AND ib.branch_id = $2
       AND ib.stock_location_id = sl.id AND ib.product_id = p.id
     WHERE p.organization_id = $1 AND p.id = ANY($4::text[])
       AND p.is_active = true AND p.deleted_at IS NULL`,
    [command.organizationId, command.branchId, stockLocationId, productIds],
  );
  if (products.rowCount !== productIds.length) {
    throw new RemoteCommandError("invalid-argument", "A count product is outside the active scope.");
  }
  const startedAt = optionalTimestamp(command.payload, "startedAt") ?? new Date();
  await client.query(
    `INSERT INTO stock_counts (
       id, organization_id, branch_id, stock_location_id, operation_id,
       count_type, status, notes, started_by_user_id, started_at,
       version, created_at, updated_at
     ) VALUES ($1, $2, $3, $4, $5, $6, 'in_progress', $7, $8, $9, 0, now(), now())`,
    [
      id,
      command.organizationId,
      command.branchId,
      stockLocationId,
      command.operationId,
      countType,
      optionalString(command.payload, "notes"),
      command.actorUserId,
      startedAt,
    ],
  );
  const items = products.rows.map((product) => ({
    id: clientItems?.find((item) => item.productId === product.id)?.id ?? randomUUID(),
    productId: product.id,
    expectedQuantityMilli: Number(product.expected_quantity_milli),
  }));
  await client.query(
    `INSERT INTO stock_count_items (
       id, organization_id, stock_count_id, product_id,
       expected_quantity_milli, version, created_at, updated_at
     )
     SELECT item.id, $1, $2, item.product_id, item.expected_quantity_milli, 0, now(), now()
     FROM jsonb_to_recordset($3::jsonb) AS item(
       id text, product_id text, expected_quantity_milli bigint
     )`,
    [
      command.organizationId,
      id,
      JSON.stringify(items.map((item) => ({
        id: item.id,
        product_id: item.productId,
        expected_quantity_milli: item.expectedQuantityMilli,
      }))),
    ],
  );
  return {
    stockCount: {id, status: "in_progress", version: 0, startedAt: startedAt.toISOString()},
    items,
  };
}

async function recordStockCountItem(
  client: PoolClient,
  command: AuthorizedCommand,
): Promise<CommandResult> {
  const stockCountId = requiredString(command.payload, "stockCountId");
  const itemId = requiredString(command.payload, "itemId");
  const countedQuantityMilli = requiredInteger(command.payload, "countedQuantityMilli");
  const expectedVersion = requiredInteger(command.payload, "expectedVersion");
  if (stockCountId !== command.aggregateId || countedQuantityMilli < 0 || expectedVersion < 0) {
    throw new RemoteCommandError("invalid-argument", "The count item update is invalid.");
  }
  const result = await client.query(
    `UPDATE stock_count_items item SET
       counted_quantity_milli = $5,
       variance_quantity_milli = $5 - item.expected_quantity_milli,
       counted_by_user_id = $6,
       counted_at = now(),
       version = item.version + 1,
       updated_at = now()
     FROM stock_counts count
     WHERE item.id = $1 AND item.stock_count_id = count.id
       AND item.organization_id = $2 AND count.organization_id = $2
       AND count.branch_id = $3 AND count.id = $4
       AND count.status = 'in_progress' AND item.version = $7
     RETURNING item.id, item.counted_quantity_milli,
       item.variance_quantity_milli, item.version`,
    [
      itemId,
      command.organizationId,
      command.branchId,
      stockCountId,
      countedQuantityMilli,
      command.actorUserId,
      expectedVersion,
    ],
  );
  if (result.rowCount !== 1) {
    throw new RemoteCommandError("aborted", "The count item changed or the count is closed.");
  }
  return {stockCountItem: result.rows[0]};
}

async function completeStockCount(
  client: PoolClient,
  command: AuthorizedCommand,
): Promise<CommandResult> {
  const stockCountId = requiredString(command.payload, "stockCountId");
  const expectedVersion = requiredInteger(command.payload, "expectedVersion");
  if (stockCountId !== command.aggregateId || expectedVersion < 0) {
    throw new RemoteCommandError("invalid-argument", "The stock count completion is invalid.");
  }
  const count = await client.query<{
    stock_location_id: string;
    product_id: string;
    expected_quantity_milli: string;
    counted_quantity_milli: string | null;
  }>(
    `SELECT count.stock_location_id, item.product_id,
       item.expected_quantity_milli, item.counted_quantity_milli
     FROM stock_counts count
     INNER JOIN stock_count_items item ON item.stock_count_id = count.id
     WHERE count.id = $1 AND count.organization_id = $2 AND count.branch_id = $3
       AND count.status = 'in_progress' AND count.version = $4
     FOR UPDATE OF count, item`,
    [stockCountId, command.organizationId, command.branchId, expectedVersion],
  );
  if (count.rowCount === 0) {
    throw new RemoteCommandError("aborted", "The stock count changed or is not open.");
  }
  if (count.rows.some((item) => item.counted_quantity_milli === null)) {
    throw new RemoteCommandError("failed-precondition", "Every stock count item must be counted.");
  }
  const correctionLines = count.rows
    .map((item) => ({
      stockLocationId: item.stock_location_id,
      productId: item.product_id,
      quantityDeltaMilli:
        Number(item.counted_quantity_milli) - Number(item.expected_quantity_milli),
    }))
    .filter((item) => item.quantityDeltaMilli !== 0);
  const correctionTransactionId = correctionLines.length === 0 ? null :
    requiredString(command.payload, "correctionTransactionId");
  let inventory: CommandResult | null = null;
  if (correctionTransactionId !== null) {
    inventory = await postInventoryTransaction(client, {
      ...command,
      commandType: "inventory.transaction.post",
      aggregateType: "inventory_transaction",
      aggregateId: correctionTransactionId,
      payload: {
        id: correctionTransactionId,
        transactionType: "stock_count_correction",
        reasonCode: "STOCK_COUNT_VARIANCE",
        referenceType: "stock_count",
        referenceId: stockCountId,
        lines: correctionLines,
      },
    });
  }
  const completed = await client.query(
    `UPDATE stock_counts SET
       completion_operation_id = $4,
       status = 'completed',
       completed_by_user_id = $5,
       completed_at = now(),
       version = version + 1,
       updated_at = now()
     WHERE id = $1 AND organization_id = $2 AND branch_id = $3
       AND status = 'in_progress' AND version = $6
     RETURNING id, status, version, completed_at`,
    [
      stockCountId,
      command.organizationId,
      command.branchId,
      command.operationId,
      command.actorUserId,
      expectedVersion,
    ],
  );
  if (completed.rowCount !== 1) {
    throw new RemoteCommandError("aborted", "The stock count changed before completion.");
  }
  return {
    stockCount: completed.rows[0],
    correctionTransactionId,
    correctionLines,
    inventory,
  };
}

async function cancelStockCount(
  client: PoolClient,
  command: AuthorizedCommand,
): Promise<CommandResult> {
  const stockCountId = requiredString(command.payload, "stockCountId");
  const expectedVersion = requiredInteger(command.payload, "expectedVersion");
  if (stockCountId !== command.aggregateId || expectedVersion < 0) {
    throw new RemoteCommandError("invalid-argument", "The stock count cancellation is invalid.");
  }
  const result = await client.query(
    `UPDATE stock_counts SET
       status = 'cancelled', version = version + 1, updated_at = now()
     WHERE id = $1 AND organization_id = $2 AND branch_id = $3
       AND status = 'in_progress' AND version = $4
     RETURNING id, status, version`,
    [stockCountId, command.organizationId, command.branchId, expectedVersion],
  );
  if (result.rowCount !== 1) {
    throw new RemoteCommandError("aborted", "The stock count changed before cancellation.");
  }
  return {stockCount: result.rows[0]};
}
