import {PoolClient} from "pg";

import {
  AuthorizedCommand,
  CommandResult,
  RemoteCommandError,
  asObject,
  normalizeSearch,
  optionalString,
  optionalTimestamp,
  requiredArray,
  requiredBoolean,
  requiredInteger,
  requiredString,
  roundDivide,
} from "./command_types";
import {postInventoryTransaction} from "./inventory_commands";

type PurchaseOrderRow = {
  id: string;
  supplier_id: string;
  order_number: string;
  status: string;
  version: number;
};

type PurchaseItemRow = {
  id: string;
  product_id: string;
  ordered_quantity_milli: string;
  received_quantity_milli: string;
  cancelled_quantity_milli: string;
  unit_cost_minor: string;
  version: number;
};

type ReceiptLine = {
  id: string;
  purchaseOrderItemId: string;
  receivedQuantityMilli: number;
  unitCostMinor: number;
  freightCostMinor: number;
  dutyCostMinor: number;
  otherLandedCostMinor: number;
};

export async function applyPurchaseCommand(
  client: PoolClient,
  command: AuthorizedCommand,
): Promise<CommandResult> {
  switch (command.commandType) {
    case "supplier.create":
      return createSupplier(client, command);
    case "supplier.archive":
      return archiveSupplier(client, command);
    case "purchase_order.create":
      return createPurchaseOrder(client, command);
    case "purchase_order.submit":
      return transitionPurchaseOrder(client, command, "draft", "submitted");
    case "purchase_order.approve":
      return transitionPurchaseOrder(client, command, "submitted", "approved");
    case "purchase_order.cancel":
      return cancelPurchaseOrder(client, command);
    case "purchase_order.receive":
      return receivePurchaseOrder(client, command);
    default:
      throw new RemoteCommandError(
        "invalid-argument",
        `Unsupported purchasing command: ${command.commandType}.`,
      );
  }
}

async function createSupplier(
  client: PoolClient,
  command: AuthorizedCommand,
): Promise<CommandResult> {
  const payload = command.payload;
  const id = requiredString(payload, "id");
  const code = requiredString(payload, "code");
  const name = requiredString(payload, "name");
  const paymentTermsDays = requiredInteger(payload, "paymentTermsDays");
  if (id !== command.aggregateId || paymentTermsDays < 0) {
    throw new RemoteCommandError("invalid-argument", "The supplier is invalid.");
  }
  const contacts = requiredArray(payload, "contacts").map((value, index) => {
    const input = asObject(value, `contacts[${index}]`);
    const email = optionalString(input, "email");
    const phone = optionalString(input, "phone");
    if (email === null && phone === null) {
      throw new RemoteCommandError(
        "invalid-argument",
        "A supplier contact requires an email or phone.",
      );
    }
    return {
      id: requiredString(input, "id"),
      name: requiredString(input, "name"),
      role: optionalString(input, "role"),
      email,
      phone,
      isPrimary: requiredBoolean(input, "isPrimary"),
    };
  });
  if (contacts.filter((contact) => contact.isPrimary).length > 1) {
    throw new RemoteCommandError(
      "invalid-argument",
      "Only one supplier contact can be primary.",
    );
  }
  const createdAt = optionalTimestamp(payload, "createdAt") ?? new Date();
  await client.query(
    `INSERT INTO suppliers (
       id, organization_id, code, normalized_code, name, normalized_name,
       tax_identifier, payment_terms_days, is_active, version,
       created_at, updated_at
     ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, true, 0, $9, $9)`,
    [
      id,
      command.organizationId,
      code,
      normalizeSearch(code),
      name,
      normalizeSearch(name),
      optionalString(payload, "taxIdentifier"),
      paymentTermsDays,
      createdAt,
    ],
  );
  for (const contact of contacts) {
    await client.query(
      `INSERT INTO supplier_contacts (
         id, organization_id, supplier_id, name, role, email, phone,
         is_primary, created_at, updated_at
       ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $9)`,
      [
        contact.id,
        command.organizationId,
        id,
        contact.name,
        contact.role,
        contact.email,
        contact.phone,
        contact.isPrimary,
        createdAt,
      ],
    );
  }
  return supplierResult(client, command.organizationId, id);
}

async function archiveSupplier(
  client: PoolClient,
  command: AuthorizedCommand,
): Promise<CommandResult> {
  const id = requiredString(command.payload, "id");
  const expectedVersion = requiredInteger(command.payload, "expectedVersion");
  if (id !== command.aggregateId || expectedVersion < 0) {
    throw new RemoteCommandError("invalid-argument", "The supplier version is invalid.");
  }
  const result = await client.query(
    `UPDATE suppliers SET is_active = false, deleted_at = now(),
       version = version + 1, updated_at = now()
     WHERE id = $1 AND organization_id = $2 AND version = $3
       AND deleted_at IS NULL`,
    [id, command.organizationId, expectedVersion],
  );
  if (result.rowCount !== 1) {
    throw new RemoteCommandError("aborted", "The remote supplier changed.");
  }
  return supplierResult(client, command.organizationId, id);
}

async function createPurchaseOrder(
  client: PoolClient,
  command: AuthorizedCommand,
): Promise<CommandResult> {
  const payload = command.payload;
  const id = requiredString(payload, "id");
  const supplierId = requiredString(payload, "supplierId");
  if (id !== command.aggregateId) {
    throw new RemoteCommandError("invalid-argument", "Purchase order IDs do not match.");
  }
  const supplier = await client.query(
    `SELECT 1 FROM suppliers WHERE id = $1 AND organization_id = $2
       AND is_active = true AND deleted_at IS NULL`,
    [supplierId, command.organizationId],
  );
  if (supplier.rowCount !== 1) {
    throw new RemoteCommandError("not-found", "The supplier is unavailable.");
  }
  const lines = requiredArray(payload, "lines").map((value, index) => {
    const line = asObject(value, `lines[${index}]`);
    const orderedQuantityMilli = requiredInteger(line, "orderedQuantityMilli");
    const unitCostMinor = requiredInteger(line, "unitCostMinor");
    const estimatedLandedCostMinor = requiredInteger(
      line,
      "estimatedLandedCostMinor",
    );
    if (orderedQuantityMilli <= 0 || unitCostMinor < 0 ||
        estimatedLandedCostMinor < 0) {
      throw new RemoteCommandError("invalid-argument", "A purchase item is invalid.");
    }
    return {
      id: requiredString(line, "id"),
      productId: requiredString(line, "productId"),
      orderedQuantityMilli,
      unitCostMinor,
      estimatedLandedCostMinor,
    };
  });
  if (lines.length === 0 ||
      new Set(lines.map((line) => line.productId)).size !== lines.length) {
    throw new RemoteCommandError(
      "invalid-argument",
      "Purchase order items must be non-empty and unique.",
    );
  }
  const createdAt = optionalTimestamp(payload, "createdAt") ?? new Date();
  await client.query(
    `INSERT INTO purchase_orders (
       id, organization_id, branch_id, supplier_id, order_number, status,
       notes, expected_delivery_at, created_by_user_id, version,
       created_at, updated_at
     ) VALUES ($1, $2, $3, $4, $5, 'draft', $6, $7, $8, 0, $9, $9)`,
    [
      id,
      command.organizationId,
      command.branchId,
      supplierId,
      requiredString(payload, "orderNumber"),
      optionalString(payload, "notes"),
      optionalTimestamp(payload, "expectedDeliveryAt"),
      command.actorUserId,
      createdAt,
    ],
  );
  for (const line of lines) {
    const product = await client.query(
      `SELECT 1 FROM products WHERE id = $1 AND organization_id = $2
         AND is_active = true AND deleted_at IS NULL`,
      [line.productId, command.organizationId],
    );
    if (product.rowCount !== 1) {
      throw new RemoteCommandError("not-found", "A purchase product is unavailable.");
    }
    await client.query(
      `INSERT INTO purchase_order_items (
         id, organization_id, branch_id, purchase_order_id, product_id,
         ordered_quantity_milli, received_quantity_milli,
         cancelled_quantity_milli, unit_cost_minor,
         estimated_landed_cost_minor, version, created_at, updated_at
       ) VALUES ($1, $2, $3, $4, $5, $6, 0, 0, $7, $8, 0, $9, $9)`,
      [
        line.id,
        command.organizationId,
        command.branchId,
        id,
        line.productId,
        line.orderedQuantityMilli,
        line.unitCostMinor,
        line.estimatedLandedCostMinor,
        createdAt,
      ],
    );
  }
  return purchaseResult(client, command, id);
}

async function transitionPurchaseOrder(
  client: PoolClient,
  command: AuthorizedCommand,
  fromStatus: string,
  toStatus: string,
): Promise<CommandResult> {
  const order = await requirePurchaseOrder(client, command);
  requireOrderState(order, fromStatus, command.payload);
  const occurredAt = optionalTimestamp(command.payload, "occurredAt") ?? new Date();
  const result = await client.query(
    `UPDATE purchase_orders SET
       status = $4,
       submitted_at = CASE WHEN $4 = 'submitted' THEN $5 ELSE submitted_at END,
       approved_at = CASE WHEN $4 = 'approved' THEN $5 ELSE approved_at END,
       approved_by_user_id = CASE WHEN $4 = 'approved' THEN $6 ELSE approved_by_user_id END,
       version = version + 1, updated_at = $5
     WHERE id = $1 AND organization_id = $2 AND branch_id = $3
       AND version = $7`,
    [
      order.id,
      command.organizationId,
      command.branchId,
      toStatus,
      occurredAt,
      command.actorUserId,
      order.version,
    ],
  );
  if (result.rowCount !== 1) {
    throw new RemoteCommandError("aborted", "The remote purchase order changed.");
  }
  return purchaseResult(client, command, order.id);
}

async function cancelPurchaseOrder(
  client: PoolClient,
  command: AuthorizedCommand,
): Promise<CommandResult> {
  const order = await requirePurchaseOrder(client, command);
  const expectedVersion = requiredInteger(command.payload, "expectedVersion");
  if (order.version !== expectedVersion ||
      ["received", "cancelled"].includes(order.status)) {
    throw new RemoteCommandError("failed-precondition", "The purchase order cannot be cancelled.");
  }
  await client.query(
    `UPDATE purchase_order_items SET
       cancelled_quantity_milli = ordered_quantity_milli - received_quantity_milli,
       version = version + 1, updated_at = now()
     WHERE purchase_order_id = $1 AND organization_id = $2 AND branch_id = $3`,
    [order.id, command.organizationId, command.branchId],
  );
  await client.query(
    `UPDATE purchase_orders SET status = 'cancelled', cancellation_reason = $4,
       cancelled_at = now(), version = version + 1, updated_at = now()
     WHERE id = $1 AND organization_id = $2 AND branch_id = $3 AND version = $5`,
    [
      order.id,
      command.organizationId,
      command.branchId,
      requiredString(command.payload, "reason"),
      order.version,
    ],
  );
  return purchaseResult(client, command, order.id);
}

async function receivePurchaseOrder(
  client: PoolClient,
  command: AuthorizedCommand,
): Promise<CommandResult> {
  const order = await requirePurchaseOrder(client, command);
  const expectedVersion = requiredInteger(command.payload, "expectedVersion");
  if (order.version !== expectedVersion ||
      !["approved", "partially_received"].includes(order.status)) {
    throw new RemoteCommandError(
      "failed-precondition",
      "Only an unchanged approved purchase order can be received.",
    );
  }
  const stockLocationId = requiredString(command.payload, "stockLocationId");
  const location = await client.query(
    `SELECT 1 FROM stock_locations WHERE id = $1 AND organization_id = $2
       AND branch_id = $3 AND is_active = true AND deleted_at IS NULL
       AND location_type <> 'damaged'`,
    [stockLocationId, command.organizationId, command.branchId],
  );
  if (location.rowCount !== 1) {
    throw new RemoteCommandError("not-found", "The receiving location is unavailable.");
  }
  const lines = parseReceiptLines(command.payload);
  const itemRows = new Map<string, PurchaseItemRow>();
  const beforeBalances = new Map<string, {quantity: number; cost: number}>();
  for (const line of lines) {
    const item = await client.query<PurchaseItemRow>(
      `SELECT id, product_id, ordered_quantity_milli,
              received_quantity_milli, cancelled_quantity_milli,
              unit_cost_minor, version
       FROM purchase_order_items
       WHERE id = $1 AND purchase_order_id = $2 AND organization_id = $3
         AND branch_id = $4 FOR UPDATE`,
      [line.purchaseOrderItemId, order.id, command.organizationId, command.branchId],
    );
    if (item.rowCount !== 1) {
      throw new RemoteCommandError("not-found", "A receipt item is outside the order.");
    }
    const row = item.rows[0];
    const remaining = Number(row.ordered_quantity_milli) -
      Number(row.received_quantity_milli) - Number(row.cancelled_quantity_milli);
    if (line.receivedQuantityMilli > remaining) {
      throw new RemoteCommandError(
        "failed-precondition",
        "A receipt quantity exceeds the ordered remainder.",
      );
    }
    itemRows.set(line.purchaseOrderItemId, row);
    const balance = await client.query<{
      on_hand_milli: string;
      weighted_average_cost_minor: string;
    }>(
      `SELECT on_hand_milli, weighted_average_cost_minor
       FROM inventory_balances
       WHERE organization_id = $1 AND branch_id = $2
         AND stock_location_id = $3 AND product_id = $4 FOR UPDATE`,
      [command.organizationId, command.branchId, stockLocationId, row.product_id],
    );
    beforeBalances.set(row.product_id, balance.rowCount === 0 ?
      {quantity: 0, cost: 0} : {
        quantity: Number(balance.rows[0].on_hand_milli),
        cost: Number(balance.rows[0].weighted_average_cost_minor),
      });
  }
  const inventoryTransactionId = requiredString(
    command.payload,
    "inventoryTransactionId",
  );
  const receivedAt = optionalTimestamp(command.payload, "receivedAt") ?? new Date();
  const inventory = await postInventoryTransaction(client, {
    ...command,
    operationId: `${command.operationId}:inventory`,
    aggregateType: "inventory_transaction",
    aggregateId: inventoryTransactionId,
    commandType: "inventory.transaction.post",
    payload: {
      id: inventoryTransactionId,
      transactionType: "purchase_receipt",
      reasonCode: "purchase_receipt",
      notes: optionalString(command.payload, "notes"),
      referenceType: "goods_receipt",
      referenceId: requiredString(command.payload, "receiptId"),
      occurredAt: receivedAt.toISOString(),
      lines: lines.map((line) => ({
        stockLocationId,
        productId: itemRows.get(line.purchaseOrderItemId)!.product_id,
        quantityDeltaMilli: line.receivedQuantityMilli,
      })),
    },
  });
  const receiptId = requiredString(command.payload, "receiptId");
  await client.query(
    `INSERT INTO goods_receipts (
       id, organization_id, branch_id, purchase_order_id, supplier_id,
       stock_location_id, receipt_number, operation_id,
       supplier_document_number, notes, received_by_user_id,
       received_at, created_at
     ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, now())`,
    [
      receiptId,
      command.organizationId,
      command.branchId,
      order.id,
      order.supplier_id,
      stockLocationId,
      requiredString(command.payload, "receiptNumber"),
      command.operationId,
      optionalString(command.payload, "supplierDocumentNumber"),
      optionalString(command.payload, "notes"),
      command.actorUserId,
      receivedAt,
    ],
  );
  for (const line of lines) {
    const item = itemRows.get(line.purchaseOrderItemId)!;
    const before = beforeBalances.get(item.product_id)!;
    const landedUnitCost = landedUnitCostMinor(line);
    const averageCost = before.quantity <= 0 ? landedUnitCost : roundDivide(
      before.quantity * before.cost +
        line.receivedQuantityMilli * landedUnitCost,
      before.quantity + line.receivedQuantityMilli,
    );
    await client.query(
      `UPDATE inventory_balances SET weighted_average_cost_minor = $5,
         updated_at = now()
       WHERE organization_id = $1 AND branch_id = $2
         AND stock_location_id = $3 AND product_id = $4`,
      [
        command.organizationId,
        command.branchId,
        stockLocationId,
        item.product_id,
        averageCost,
      ],
    );
    const inventoryBalances = inventory.balances;
    if (Array.isArray(inventoryBalances)) {
      const balance = inventoryBalances.find((value) => {
        const candidate = value as Record<string, unknown>;
        return candidate.stockLocationId === stockLocationId &&
          candidate.productId === item.product_id;
      }) as Record<string, unknown> | undefined;
      if (balance !== undefined) balance.weightedAverageCostMinor = averageCost;
    }
    await client.query(
      `INSERT INTO goods_receipt_items (
         id, organization_id, branch_id, goods_receipt_id,
         purchase_order_item_id, product_id, inventory_transaction_id,
         received_quantity_milli, unit_cost_minor, freight_cost_minor,
         duty_cost_minor, other_landed_cost_minor, landed_unit_cost_minor,
         weighted_average_cost_minor_after, created_at
       ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12,
                 $13, $14, now())`,
      [
        line.id,
        command.organizationId,
        command.branchId,
        receiptId,
        item.id,
        item.product_id,
        inventoryTransactionId,
        line.receivedQuantityMilli,
        line.unitCostMinor,
        line.freightCostMinor,
        line.dutyCostMinor,
        line.otherLandedCostMinor,
        landedUnitCost,
        averageCost,
      ],
    );
    await client.query(
      `UPDATE purchase_order_items SET
         received_quantity_milli = received_quantity_milli + $2,
         version = version + 1, updated_at = now()
       WHERE id = $1 AND version = $3`,
      [item.id, line.receivedQuantityMilli, item.version],
    );
  }
  const remaining = await client.query<{remaining: string}>(
    `SELECT COALESCE(SUM(
       ordered_quantity_milli - received_quantity_milli - cancelled_quantity_milli
     ), 0)::text AS remaining
     FROM purchase_order_items WHERE purchase_order_id = $1`,
    [order.id],
  );
  await client.query(
    `UPDATE purchase_orders SET status = $4, version = version + 1,
       updated_at = now()
     WHERE id = $1 AND organization_id = $2 AND branch_id = $3 AND version = $5`,
    [
      order.id,
      command.organizationId,
      command.branchId,
      Number(remaining.rows[0].remaining) === 0 ? "received" : "partially_received",
      order.version,
    ],
  );
  return {
    ...(await purchaseResult(client, command, order.id)),
    inventory,
  };
}

function parseReceiptLines(payload: Record<string, unknown>): ReceiptLine[] {
  const lines = requiredArray(payload, "lines").map((value, index) => {
    const line = asObject(value, `lines[${index}]`);
    const parsed = {
      id: requiredString(line, "id"),
      purchaseOrderItemId: requiredString(line, "purchaseOrderItemId"),
      receivedQuantityMilli: requiredInteger(line, "receivedQuantityMilli"),
      unitCostMinor: requiredInteger(line, "unitCostMinor"),
      freightCostMinor: requiredInteger(line, "freightCostMinor"),
      dutyCostMinor: requiredInteger(line, "dutyCostMinor"),
      otherLandedCostMinor: requiredInteger(line, "otherLandedCostMinor"),
    };
    if (parsed.receivedQuantityMilli <= 0 || parsed.unitCostMinor < 0 ||
        parsed.freightCostMinor < 0 || parsed.dutyCostMinor < 0 ||
        parsed.otherLandedCostMinor < 0) {
      throw new RemoteCommandError("invalid-argument", "A receipt cost is invalid.");
    }
    return parsed;
  });
  if (lines.length === 0 ||
      new Set(lines.map((line) => line.purchaseOrderItemId)).size !== lines.length) {
    throw new RemoteCommandError("invalid-argument", "Receipt items must be non-empty and unique.");
  }
  return lines;
}

function landedUnitCostMinor(line: ReceiptLine): number {
  const base = roundDivide(
    line.receivedQuantityMilli * line.unitCostMinor,
    1000,
  );
  return roundDivide(
    (base + line.freightCostMinor + line.dutyCostMinor +
      line.otherLandedCostMinor) * 1000,
    line.receivedQuantityMilli,
  );
}

async function requirePurchaseOrder(
  client: PoolClient,
  command: AuthorizedCommand,
): Promise<PurchaseOrderRow> {
  const id = requiredString(command.payload, "id");
  if (id !== command.aggregateId) {
    throw new RemoteCommandError("invalid-argument", "Purchase order IDs do not match.");
  }
  const result = await client.query<PurchaseOrderRow>(
    `SELECT id, supplier_id, order_number, status, version
     FROM purchase_orders WHERE id = $1 AND organization_id = $2
       AND branch_id = $3 FOR UPDATE`,
    [id, command.organizationId, command.branchId],
  );
  if (result.rowCount !== 1) {
    throw new RemoteCommandError("not-found", "The purchase order does not exist.");
  }
  return result.rows[0];
}

function requireOrderState(
  order: PurchaseOrderRow,
  expectedStatus: string,
  payload: Record<string, unknown>,
): void {
  const expectedVersion = requiredInteger(payload, "expectedVersion");
  if (order.status !== expectedStatus || order.version !== expectedVersion) {
    throw new RemoteCommandError(
      "failed-precondition",
      "The remote purchase order state changed.",
    );
  }
}

async function supplierResult(
  client: PoolClient,
  organizationId: string,
  supplierId: string,
): Promise<CommandResult> {
  const supplier = await client.query(
    `SELECT id, code, name, tax_identifier AS "taxIdentifier",
            payment_terms_days AS "paymentTermsDays",
            is_active AS "isActive", version,
            created_at AS "createdAt", updated_at AS "updatedAt",
            deleted_at AS "deletedAt"
     FROM suppliers WHERE id = $1 AND organization_id = $2`,
    [supplierId, organizationId],
  );
  const contacts = await client.query(
    `SELECT id, name, role, email, phone, is_primary AS "isPrimary"
     FROM supplier_contacts WHERE supplier_id = $1 AND organization_id = $2
     ORDER BY is_primary DESC, name`,
    [supplierId, organizationId],
  );
  return {supplier: supplier.rows[0], contacts: contacts.rows};
}

async function purchaseResult(
  client: PoolClient,
  command: AuthorizedCommand,
  purchaseOrderId: string,
): Promise<CommandResult> {
  const order = await client.query(
    `SELECT id, supplier_id AS "supplierId", order_number AS "orderNumber",
            status, notes, expected_delivery_at AS "expectedDeliveryAt",
            created_by_user_id AS "createdByUserId",
            approved_by_user_id AS "approvedByUserId",
            cancellation_reason AS "cancellationReason",
            submitted_at AS "submittedAt", approved_at AS "approvedAt",
            cancelled_at AS "cancelledAt", version,
            created_at AS "createdAt", updated_at AS "updatedAt"
     FROM purchase_orders WHERE id = $1 AND organization_id = $2
       AND branch_id = $3`,
    [purchaseOrderId, command.organizationId, command.branchId],
  );
  const items = await client.query(
    `SELECT id, product_id AS "productId",
            ordered_quantity_milli::bigint AS "orderedQuantityMilli",
            received_quantity_milli::bigint AS "receivedQuantityMilli",
            cancelled_quantity_milli::bigint AS "cancelledQuantityMilli",
            unit_cost_minor::bigint AS "unitCostMinor",
            estimated_landed_cost_minor::bigint AS "estimatedLandedCostMinor",
            version
     FROM purchase_order_items WHERE purchase_order_id = $1
     ORDER BY created_at`,
    [purchaseOrderId],
  );
  const receipts = await client.query(
    `SELECT id, stock_location_id AS "stockLocationId",
            receipt_number AS "receiptNumber",
            operation_id AS "operationId",
            supplier_document_number AS "supplierDocumentNumber", notes,
            received_by_user_id AS "receivedByUserId",
            received_at AS "receivedAt"
     FROM goods_receipts WHERE purchase_order_id = $1
     ORDER BY received_at`,
    [purchaseOrderId],
  );
  const receiptItems = await client.query(
    `SELECT gri.id, gri.goods_receipt_id AS "goodsReceiptId",
            gri.purchase_order_item_id AS "purchaseOrderItemId",
            gri.product_id AS "productId",
            gri.inventory_transaction_id AS "inventoryTransactionId",
            gri.received_quantity_milli::bigint AS "receivedQuantityMilli",
            gri.unit_cost_minor::bigint AS "unitCostMinor",
            gri.freight_cost_minor::bigint AS "freightCostMinor",
            gri.duty_cost_minor::bigint AS "dutyCostMinor",
            gri.other_landed_cost_minor::bigint AS "otherLandedCostMinor",
            gri.landed_unit_cost_minor::bigint AS "landedUnitCostMinor",
            gri.weighted_average_cost_minor_after::bigint
              AS "weightedAverageCostMinorAfter"
     FROM goods_receipt_items gri
     INNER JOIN goods_receipts gr ON gr.id = gri.goods_receipt_id
     WHERE gr.purchase_order_id = $1 ORDER BY gri.created_at`,
    [purchaseOrderId],
  );
  return {
    purchaseOrder: order.rows[0],
    items: items.rows.map(numericPurchaseItem),
    receipts: receipts.rows,
    receiptItems: receiptItems.rows.map(numericReceiptItem),
  };
}

function numericPurchaseItem(row: Record<string, unknown>): Record<string, unknown> {
  return {
    ...row,
    orderedQuantityMilli: Number(row.orderedQuantityMilli),
    receivedQuantityMilli: Number(row.receivedQuantityMilli),
    cancelledQuantityMilli: Number(row.cancelledQuantityMilli),
    unitCostMinor: Number(row.unitCostMinor),
    estimatedLandedCostMinor: Number(row.estimatedLandedCostMinor),
  };
}

function numericReceiptItem(row: Record<string, unknown>): Record<string, unknown> {
  return {
    ...row,
    receivedQuantityMilli: Number(row.receivedQuantityMilli),
    unitCostMinor: Number(row.unitCostMinor),
    freightCostMinor: Number(row.freightCostMinor),
    dutyCostMinor: Number(row.dutyCostMinor),
    otherLandedCostMinor: Number(row.otherLandedCostMinor),
    landedUnitCostMinor: Number(row.landedUnitCostMinor),
    weightedAverageCostMinorAfter: Number(row.weightedAverageCostMinorAfter),
  };
}
