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
  roundDivide,
} from "./command_types";
import {postInventoryTransaction} from "./inventory_commands";

type SaleRow = {
  id: string;
  status: string;
  completed_at: Date;
};

type BranchPolicyRow = {
  return_approval_threshold_minor: string | null;
  void_window_minutes: number;
};

type SaleItemRow = {
  id: string;
  line_number: number;
  product_id: string;
  quantity_milli: string;
  gross_amount_minor: string;
  discount_amount_minor: string;
  tax_amount_minor: string;
  total_amount_minor: string;
};

type PriorRow = {
  sale_item_id: string;
  quantity_milli: string;
  subtotal_minor: string;
  discount_minor: string;
  tax_minor: string;
  total_minor: string;
};

type CorrectionLine = {
  saleItemId: string;
  lineNumber: number;
  productId: string;
  quantityMilli: number;
  disposition: "restock" | "damaged" | "non_restock";
  destinationStockLocationId: string | null;
  subtotalMinor: number;
  discountMinor: number;
  taxMinor: number;
  totalMinor: number;
};

type Refund = {
  method: "cash" | "card" | "e_wallet" | "store_credit";
  amountMinor: number;
  reference: string | null;
};

export async function correctSale(
  client: PoolClient,
  command: AuthorizedCommand,
): Promise<CommandResult> {
  const expectedType = command.commandType === "sale.void" ? "void" :
    command.commandType === "sale.return" ? "return" : null;
  if (expectedType === null) {
    throw new RemoteCommandError(
      "invalid-argument",
      `Unsupported sale correction command: ${command.commandType}.`,
    );
  }
  const payload = command.payload;
  const correctionId = requiredString(payload, "id");
  const saleId = requiredString(payload, "saleId");
  const correctionType = requiredString(payload, "correctionType");
  if (correctionId !== command.aggregateId || correctionType !== expectedType) {
    throw new RemoteCommandError(
      "invalid-argument",
      "Sale correction identifiers do not match.",
    );
  }

  const saleResult = await client.query<SaleRow>(
    `SELECT id, status, completed_at
     FROM sales
     WHERE id = $1 AND organization_id = $2 AND branch_id = $3
     FOR UPDATE`,
    [saleId, command.organizationId, command.branchId],
  );
  if (saleResult.rowCount !== 1 || saleResult.rows[0].status !== "completed") {
    throw new RemoteCommandError(
      "failed-precondition",
      "Only a completed sale can be returned or voided.",
    );
  }
  const itemResult = await client.query<SaleItemRow>(
    `SELECT id, line_number, product_id, quantity_milli,
            gross_amount_minor, discount_amount_minor, tax_amount_minor,
            total_amount_minor
     FROM sale_items
     WHERE sale_id = $1 AND organization_id = $2 AND branch_id = $3
     ORDER BY line_number`,
    [saleId, command.organizationId, command.branchId],
  );
  const priorResult = await client.query<PriorRow>(
    `SELECT sri.sale_item_id,
            SUM(sri.quantity_milli)::text AS quantity_milli,
            SUM(sri.subtotal_minor)::text AS subtotal_minor,
            SUM(sri.discount_minor)::text AS discount_minor,
            SUM(sri.tax_minor)::text AS tax_minor,
            SUM(sri.total_minor)::text AS total_minor
     FROM sale_return_items sri
     INNER JOIN sale_returns sr ON sr.id = sri.sale_return_id
     WHERE sr.sale_id = $1 AND sr.organization_id = $2
       AND sr.branch_id = $3 AND sr.status = 'completed'
     GROUP BY sri.sale_item_id`,
    [saleId, command.organizationId, command.branchId],
  );
  const priorByItem = new Map(
    priorResult.rows.map((row) => [row.sale_item_id, row]),
  );
  if (expectedType === "void" && priorResult.rows.length > 0) {
    throw new RemoteCommandError(
      "failed-precondition",
      "A sale with an existing return can no longer be voided.",
    );
  }
  const lines = await validateCorrectionLines(
    client,
    command,
    payload,
    itemResult.rows,
    priorByItem,
    expectedType,
  );
  const refunds = validateRefunds(payload, sum(lines, "totalMinor"));
  validateCorrectionHeader(payload, lines);

  const policyResult = await client.query<BranchPolicyRow>(
    `SELECT return_approval_threshold_minor, void_window_minutes
     FROM branches
     WHERE id = $1 AND organization_id = $2
       AND is_active = true AND deleted_at IS NULL`,
    [command.branchId, command.organizationId],
  );
  if (policyResult.rowCount !== 1) {
    throw new RemoteCommandError("not-found", "The active branch does not exist.");
  }
  const policy = policyResult.rows[0];
  const totalMinor = sum(lines, "totalMinor");
  const threshold = policy.return_approval_threshold_minor === null ? null :
    Number(policy.return_approval_threshold_minor);
  const elapsedMinutes = Math.floor(
    (Date.now() - saleResult.rows[0].completed_at.valueOf()) / 60000,
  );
  const requiresApproval =
    (threshold !== null && totalMinor > threshold) ||
    (expectedType === "void" && elapsedMinutes > policy.void_window_minutes);
  const approvedByUserId = optionalString(payload, "approvedByUserId");
  if (requiresApproval &&
      (approvedByUserId !== command.actorUserId ||
       !command.permissions.has("sales.corrections.approve"))) {
    throw new RemoteCommandError(
      "permission-denied",
      "Manager approval is required for this sale correction.",
    );
  }

  const completedAt = optionalTimestamp(payload, "completedAt") ?? new Date();
  const reasonCode = requiredString(payload, "reasonCode");
  const notes = optionalString(payload, "notes");
  const returnNumber = requiredString(payload, "returnNumber");
  let approvalRequestId: string | null = null;
  if (requiresApproval) {
    approvalRequestId = optionalString(payload, "approvalRequestId") ?? randomUUID();
    await insertApproval(
      client,
      command,
      approvalRequestId,
      saleId,
      expectedType,
      reasonCode,
      notes,
      threshold,
      totalMinor,
      completedAt,
    );
  }

  const inventoryLines = lines.filter(
    (line) => line.disposition !== "non_restock",
  );
  const inventoryTransactionId = inventoryLines.length === 0 ? null :
    optionalString(payload, "inventoryTransactionId") ?? randomUUID();
  const inventory = inventoryTransactionId === null ? null :
    await postInventoryTransaction(client, {
      ...command,
      operationId: `${command.operationId}:inventory`,
      commandType: "inventory.transaction.post",
      aggregateType: "inventory_transaction",
      aggregateId: inventoryTransactionId,
      payload: {
        id: inventoryTransactionId,
        transactionType: "sale_return",
        reasonCode,
        notes,
        referenceType: "sale_correction",
        referenceId: correctionId,
        approvedByUserId: requiresApproval ? approvedByUserId : null,
        occurredAt: completedAt.toISOString(),
        lines: inventoryLines.map((line) => ({
          stockLocationId: line.destinationStockLocationId,
          productId: line.productId,
          quantityDeltaMilli: line.quantityMilli,
        })),
      },
    });

  const cashRefund = refunds.find((refund) => refund.method === "cash");
  const cash = cashRefund === undefined ? null : await insertCashRefund(
    client,
    command,
    requiredString(payload, "deviceId"),
    cashRefund.amountMinor,
    returnNumber,
    reasonCode,
    approvedByUserId,
    completedAt,
  );

  await client.query(
    `INSERT INTO sale_returns (
       id, organization_id, branch_id, sale_id, operation_id, return_number,
       correction_type, status, reason_code, notes, inventory_transaction_id,
       approval_request_id, subtotal_minor, discount_minor, tax_minor,
       total_minor, created_by_user_id, approved_by_user_id, approved_at,
       completed_at, version, created_at, updated_at
     ) VALUES ($1, $2, $3, $4, $5, $6, $7, 'completed', $8, $9, $10, $11,
       $12, $13, $14, $15, $16, $17,
       CASE WHEN $17::text IS NULL THEN NULL ELSE $18 END,
       $18, 0, now(), now())`,
    [
      correctionId,
      command.organizationId,
      command.branchId,
      saleId,
      command.operationId,
      returnNumber,
      expectedType,
      reasonCode,
      notes,
      inventoryTransactionId,
      approvalRequestId,
      sum(lines, "subtotalMinor"),
      sum(lines, "discountMinor"),
      sum(lines, "taxMinor"),
      totalMinor,
      command.actorUserId,
      requiresApproval ? approvedByUserId : null,
      completedAt,
    ],
  );

  const itemResults: Record<string, unknown>[] = [];
  for (const line of lines) {
    const id = randomUUID();
    await client.query(
      `INSERT INTO sale_return_items (
         id, organization_id, branch_id, sale_return_id, sale_item_id,
         product_id, disposition, destination_stock_location_id,
         quantity_milli, subtotal_minor, discount_minor, tax_minor,
         total_minor, version, created_at, updated_at
       ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12,
         $13, 0, now(), now())`,
      [
        id,
        command.organizationId,
        command.branchId,
        correctionId,
        line.saleItemId,
        line.productId,
        line.disposition,
        line.destinationStockLocationId,
        line.quantityMilli,
        line.subtotalMinor,
        line.discountMinor,
        line.taxMinor,
        line.totalMinor,
      ],
    );
    itemResults.push({id, ...line});
  }

  const refundResults: Record<string, unknown>[] = [];
  for (const refund of refunds) {
    const id = randomUUID();
    const isCash = refund.method === "cash";
    await client.query(
      `INSERT INTO refund_payments (
         id, organization_id, branch_id, sale_return_id, shift_id,
         cash_movement_id, refund_method, amount_minor, reference,
         version, created_at, updated_at
       ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, 0, now(), now())`,
      [
        id,
        command.organizationId,
        command.branchId,
        correctionId,
        isCash ? cash!.shiftId : null,
        isCash ? cash!.id : null,
        refund.method,
        refund.amountMinor,
        refund.reference,
      ],
    );
    refundResults.push({
      id,
      ...refund,
      shiftId: isCash ? cash!.shiftId : null,
      cashMovementId: isCash ? cash!.id : null,
    });
  }

  return {
    correction: {
      id: correctionId,
      saleId,
      returnNumber,
      correctionType: expectedType,
      status: "completed",
      reasonCode,
      notes,
      inventoryTransactionId,
      approvalRequestId,
      approvedByUserId: requiresApproval ? approvedByUserId : null,
      subtotalMinor: sum(lines, "subtotalMinor"),
      discountMinor: sum(lines, "discountMinor"),
      taxMinor: sum(lines, "taxMinor"),
      totalMinor,
      completedAt: completedAt.toISOString(),
      version: 0,
    },
    items: itemResults,
    refunds: refundResults,
    inventory,
    cashMovement: cash,
  };
}

async function validateCorrectionLines(
  client: PoolClient,
  command: AuthorizedCommand,
  payload: Record<string, unknown>,
  saleItems: SaleItemRow[],
  priorByItem: Map<string, PriorRow>,
  correctionType: "return" | "void",
): Promise<CorrectionLine[]> {
  const byLine = new Map(saleItems.map((item) => [item.line_number, item]));
  const seen = new Set<number>();
  const payloadItems = requiredArray(payload, "items");
  if (correctionType === "void" && payloadItems.length !== saleItems.length) {
    throw new RemoteCommandError("invalid-argument", "A void must reverse every sale item.");
  }
  const result: CorrectionLine[] = [];
  for (let index = 0; index < payloadItems.length; index += 1) {
    const input = asObject(payloadItems[index], `items[${index}]`);
    const lineNumber = requiredInteger(input, "lineNumber");
    const item = byLine.get(lineNumber);
    if (item === undefined || !seen.add(lineNumber) ||
        requiredString(input, "productId") !== item.product_id) {
      throw new RemoteCommandError("invalid-argument", "A correction item is invalid.");
    }
    const prior = priorByItem.get(item.id);
    const soldQuantity = Number(item.quantity_milli);
    const priorQuantity = prior === undefined ? 0 : Number(prior.quantity_milli);
    const remaining = soldQuantity - priorQuantity;
    const quantity = requiredInteger(input, "quantityMilli");
    if (quantity <= 0 || quantity > remaining ||
        (correctionType === "void" && quantity !== soldQuantity)) {
      throw new RemoteCommandError(
        "failed-precondition",
        "Returned quantity exceeds the remaining sold quantity.",
      );
    }
    const disposition = requiredString(input, "disposition");
    if (!["restock", "damaged", "non_restock"].includes(disposition)) {
      throw new RemoteCommandError("invalid-argument", "Return disposition is invalid.");
    }
    const destination = optionalString(input, "destinationStockLocationId");
    if (disposition === "non_restock" && destination !== null ||
        disposition !== "non_restock" && destination === null) {
      throw new RemoteCommandError("invalid-argument", "Return destination is invalid.");
    }
    if (destination !== null) {
      const location = await client.query<{location_type: string}>(
        `SELECT location_type FROM stock_locations
         WHERE id = $1 AND organization_id = $2 AND branch_id = $3
           AND is_active = true AND deleted_at IS NULL`,
        [destination, command.organizationId, command.branchId],
      );
      const locationType = location.rows[0]?.location_type;
      if (location.rowCount !== 1 ||
          disposition === "damaged" && locationType !== "damaged" ||
          disposition === "restock" && locationType === "damaged") {
        throw new RemoteCommandError("invalid-argument", "Return destination is invalid.");
      }
    }
    const isFinal = quantity === remaining;
    const values = {
      subtotalMinor: prorate(
        Number(item.gross_amount_minor),
        prior === undefined ? 0 : Number(prior.subtotal_minor),
        soldQuantity,
        quantity,
        isFinal,
      ),
      discountMinor: prorate(
        Number(item.discount_amount_minor),
        prior === undefined ? 0 : Number(prior.discount_minor),
        soldQuantity,
        quantity,
        isFinal,
      ),
      taxMinor: prorate(
        Number(item.tax_amount_minor),
        prior === undefined ? 0 : Number(prior.tax_minor),
        soldQuantity,
        quantity,
        isFinal,
      ),
      totalMinor: prorate(
        Number(item.total_amount_minor),
        prior === undefined ? 0 : Number(prior.total_minor),
        soldQuantity,
        quantity,
        isFinal,
      ),
    };
    for (const [field, expected] of Object.entries(values)) {
      if (requiredInteger(input, field) !== expected) {
        throw new RemoteCommandError(
          "invalid-argument",
          "Sale correction amounts were recalculated and did not match.",
        );
      }
    }
    result.push({
      saleItemId: item.id,
      lineNumber,
      productId: item.product_id,
      quantityMilli: quantity,
      disposition: disposition as CorrectionLine["disposition"],
      destinationStockLocationId: destination,
      ...values,
    });
  }
  if (result.length === 0) {
    throw new RemoteCommandError("invalid-argument", "A correction requires an item.");
  }
  return result;
}

function validateRefunds(
  payload: Record<string, unknown>,
  correctionTotal: number,
): Refund[] {
  const methods = new Set<string>();
  const refunds = requiredArray(payload, "refunds").map((value, index) => {
    const input = asObject(value, `refunds[${index}]`);
    const method = requiredString(input, "method");
    const amountMinor = requiredInteger(input, "amountMinor");
    if (!methods.add(method) ||
        !["cash", "card", "e_wallet", "store_credit"].includes(method) ||
        amountMinor <= 0) {
      throw new RemoteCommandError("invalid-argument", "Refund reconciliation is invalid.");
    }
    return {
      method: method as Refund["method"],
      amountMinor,
      reference: optionalString(input, "reference"),
    };
  });
  if (refunds.length === 0 ||
      refunds.reduce((total, refund) => total + refund.amountMinor, 0) !== correctionTotal) {
    throw new RemoteCommandError("invalid-argument", "Refunds must equal the correction total.");
  }
  return refunds;
}

function validateCorrectionHeader(
  payload: Record<string, unknown>,
  lines: CorrectionLine[],
): void {
  for (const field of [
    "subtotalMinor",
    "discountMinor",
    "taxMinor",
    "totalMinor",
  ] as const) {
    if (requiredInteger(payload, field) !== sum(lines, field)) {
      throw new RemoteCommandError("invalid-argument", "Correction totals do not reconcile.");
    }
  }
}

async function insertApproval(
  client: PoolClient,
  command: AuthorizedCommand,
  approvalRequestId: string,
  saleId: string,
  correctionType: "return" | "void",
  reasonCode: string,
  notes: string | null,
  threshold: number | null,
  totalMinor: number,
  completedAt: Date,
): Promise<void> {
  await client.query(
    `INSERT INTO approval_requests (
       id, organization_id, branch_id, operation_id, request_type,
       entity_type, entity_id, status, requested_by_user_id, reason,
       threshold_minor, actual_amount_minor, requested_at, resolved_at,
       version, created_at, updated_at
     ) VALUES ($1, $2, $3, $4, $5, 'sale', $6, 'approved', $7, $8, $9,
       $10, $11, $11, 0, now(), now())`,
    [
      approvalRequestId,
      command.organizationId,
      command.branchId,
      `${command.operationId}:approval`,
      correctionType === "void" ? "sale_void" : "sale_return",
      saleId,
      command.actorUserId,
      reasonCode,
      threshold,
      totalMinor,
      completedAt,
    ],
  );
  await client.query(
    `INSERT INTO approval_decisions (
       id, organization_id, branch_id, approval_request_id, decision,
       decided_by_user_id, notes, decided_at, version, created_at, updated_at
     ) VALUES ($1, $2, $3, $4, 'approved', $5, $6, $7, 0, now(), now())`,
    [
      randomUUID(),
      command.organizationId,
      command.branchId,
      approvalRequestId,
      command.actorUserId,
      notes,
      completedAt,
    ],
  );
}

async function insertCashRefund(
  client: PoolClient,
  command: AuthorizedCommand,
  deviceId: string,
  amountMinor: number,
  returnNumber: string,
  reasonCode: string,
  approvedByUserId: string | null,
  completedAt: Date,
): Promise<{id: string; registerId: string; shiftId: string}> {
  const scope = await client.query<{register_id: string; shift_id: string}>(
    `SELECT r.id AS register_id, s.id AS shift_id
     FROM registers r
     INNER JOIN shifts s
       ON s.register_id = r.id AND s.organization_id = r.organization_id
      AND s.branch_id = r.branch_id AND s.status = 'open'
      AND s.device_id = $4 AND s.opened_by_user_id = $5
     WHERE r.organization_id = $1 AND r.branch_id = $2
       AND r.assigned_device_id = $3 AND r.is_active = true
       AND r.deleted_at IS NULL`,
    [
      command.organizationId,
      command.branchId,
      deviceId,
      deviceId,
      command.actorUserId,
    ],
  );
  if (scope.rowCount !== 1) {
    throw new RemoteCommandError(
      "failed-precondition",
      "An open shift on the assigned register is required for a cash refund.",
    );
  }
  const id = randomUUID();
  await client.query(
    `INSERT INTO cash_movements (
       id, organization_id, branch_id, register_id, shift_id, operation_id,
       movement_type, amount_minor, reason, created_by_user_id,
       approved_by_user_id, approved_at, occurred_at, version,
       created_at, updated_at
     ) VALUES ($1, $2, $3, $4, $5, $6, 'cash_out', $7, $8, $9, $10,
       CASE WHEN $10::text IS NULL THEN NULL ELSE $11 END,
       $11, 0, now(), now())`,
    [
      id,
      command.organizationId,
      command.branchId,
      scope.rows[0].register_id,
      scope.rows[0].shift_id,
      `${command.operationId}:cash_refund`,
      -amountMinor,
      `Refund ${returnNumber}: ${reasonCode}`,
      command.actorUserId,
      approvedByUserId,
      completedAt,
    ],
  );
  return {
    id,
    registerId: scope.rows[0].register_id,
    shiftId: scope.rows[0].shift_id,
  };
}

function prorate(
  original: number,
  prior: number,
  soldQuantity: number,
  quantity: number,
  isFinal: boolean,
): number {
  return isFinal ? original - prior : roundDivide(original * quantity, soldQuantity);
}

function sum(
  lines: CorrectionLine[],
  field: "subtotalMinor" | "discountMinor" | "taxMinor" | "totalMinor",
): number {
  return lines.reduce((total, line) => total + line[field], 0);
}
