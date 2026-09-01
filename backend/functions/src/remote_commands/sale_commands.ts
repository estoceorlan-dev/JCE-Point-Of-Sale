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
  roundDivide,
} from "./command_types";
import {postInventoryTransaction} from "./inventory_commands";

type SaleLine = {
  productId: string;
  stockLocationId: string;
  quantityMilli: number;
  unitPriceMinor: number;
  unitCostMinor: number;
  taxRateBasisPoints: number;
  taxInclusive: boolean;
  grossAmountMinor: number;
  discountAmountMinor: number;
  netAmountMinor: number;
  taxAmountMinor: number;
  totalAmountMinor: number;
  itemDiscountMinor: number;
  allocatedSaleDiscountMinor: number;
  itemDiscountReason: string | null;
  productName: string | null;
  sku: string | null;
  barcode: string | null;
  unitName: string | null;
};

type SalePayment = {
  method: string;
  tenderedAmountMinor: number;
  appliedAmountMinor: number;
  changeAmountMinor: number;
  reference: string | null;
};

export async function completeSale(
  client: PoolClient,
  command: AuthorizedCommand,
): Promise<CommandResult> {
  if (command.commandType !== "sale.complete") {
    throw new RemoteCommandError("invalid-argument", `Unsupported sale command: ${command.commandType}.`);
  }
  const payload = command.payload;
  const saleId = requiredString(payload, "id");
  if (saleId !== command.aggregateId) throw new RemoteCommandError("invalid-argument", "Sale IDs do not match.");
  const {lines, payments} = validateSalePayload(payload);
  const completedAt = optionalTimestamp(payload, "completedAt") ?? new Date();
  await validateSaleCatalog(client, command, lines, completedAt);
  const customerId = optionalString(payload, "customerId");
  if (customerId !== null) {
    const customer = await client.query(
      `SELECT 1 FROM customers WHERE id = $1 AND organization_id = $2
       AND status = 'active'`,
      [customerId, command.organizationId],
    );
    if (customer.rowCount !== 1) {
      throw new RemoteCommandError(
        "failed-precondition",
        "The selected customer is unavailable in this organization.",
      );
    }
  }

  const deviceId = requiredString(payload, "deviceId");
  const scope = await loadCheckoutScope(client, command, deviceId);
  const discountApprovedByUserId = optionalString(payload, "discountApprovedByUserId");
  const discountMinor = requiredInteger(payload, "discountMinor");
  const subtotalMinor = requiredInteger(payload, "subtotalMinor");
  if (scope.discountApprovalThresholdBasisPoints !== null &&
      discountMinor * 10000 > subtotalMinor * scope.discountApprovalThresholdBasisPoints) {
    if (discountApprovedByUserId !== command.actorUserId ||
        !command.permissions.has("sales.discounts.approve")) {
      throw new RemoteCommandError("permission-denied", "Sale discount approval is required.");
    }
  }
  const inventoryTransactionId =
    optionalString(payload, "inventoryTransactionId") ?? randomUUID();
  const inventory = await postInventoryTransaction(client, {
    ...command,
    operationId: `${command.operationId}:inventory`,
    commandType: "inventory.transaction.post",
    aggregateType: "inventory_transaction",
    aggregateId: inventoryTransactionId,
    payload: {
      id: inventoryTransactionId,
      transactionType: "sale",
      referenceType: "sale",
      referenceId: saleId,
      occurredAt: completedAt.toISOString(),
      lines: lines.map((line) => ({
        stockLocationId: line.stockLocationId,
        productId: line.productId,
        quantityDeltaMilli: -line.quantityMilli,
      })),
    },
  });
  const receiptNumber = await allocateReceiptNumber(
    client,
    command.organizationId,
    command.branchId,
    scope.registerId,
    scope.branchCode,
    scope.registerCode,
  );
  await client.query(
    `
      INSERT INTO sales (
        id, organization_id, branch_id, register_id, shift_id,
        inventory_transaction_id, customer_id, operation_id, receipt_number, status,
        cashier_user_id, subtotal_minor, discount_minor, tax_minor, total_minor,
        tendered_minor, change_minor, discount_approved_by_user_id,
        discount_approved_at, completed_at, version, created_at, updated_at
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, 'completed', $10, $11,
        $12, $13, $14, $15, $16, $17,
        CASE WHEN $17::text IS NULL THEN NULL ELSE now() END,
        $18, 0, now(), now())
    `,
    [
      saleId,
      command.organizationId,
      command.branchId,
      scope.registerId,
      scope.shiftId,
      inventoryTransactionId,
      customerId,
      command.operationId,
      receiptNumber,
      command.actorUserId,
      subtotalMinor,
      discountMinor,
      requiredInteger(payload, "taxMinor"),
      requiredInteger(payload, "totalMinor"),
      requiredInteger(payload, "tenderedMinor"),
      requiredInteger(payload, "changeMinor"),
      discountApprovedByUserId,
      completedAt,
    ],
  );
  const saleItemIds: string[] = [];
  for (let index = 0; index < lines.length; index += 1) {
    const line = lines[index];
    const snapshot = await loadProductSnapshot(client, command.organizationId, line);
    const saleItemId = randomUUID();
    saleItemIds.push(saleItemId);
    await client.query(
      `
        INSERT INTO sale_items (
          id, organization_id, branch_id, sale_id, product_id, stock_location_id,
          line_number, product_name_snapshot, sku_snapshot, barcode_snapshot,
          unit_name_snapshot, quantity_milli, unit_price_minor_snapshot,
          unit_cost_minor_snapshot, tax_rate_basis_points_snapshot,
          tax_inclusive_snapshot, gross_amount_minor, discount_amount_minor,
          net_amount_minor, tax_amount_minor, total_amount_minor,
          version, created_at, updated_at
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13,
          $14, $15, $16, $17, $18, $19, $20, $21, 0, now(), now())
      `,
      [saleItemId, command.organizationId, command.branchId, saleId, line.productId, line.stockLocationId, index + 1, snapshot.name, snapshot.sku, snapshot.barcode, snapshot.unitName, line.quantityMilli, line.unitPriceMinor, line.unitCostMinor, line.taxRateBasisPoints, line.taxInclusive, line.grossAmountMinor, line.discountAmountMinor, line.netAmountMinor, line.taxAmountMinor, line.totalAmountMinor],
    );
    if (line.itemDiscountMinor > 0) {
      await insertDiscount(client, command, saleId, saleItemId, "item", line.itemDiscountMinor, line.itemDiscountReason ?? "Offline item discount", discountApprovedByUserId);
    }
  }
  const saleDiscountMinor = lines.reduce(
    (total, line) => total + line.allocatedSaleDiscountMinor,
    0,
  );
  if (saleDiscountMinor > 0) {
    await insertDiscount(client, command, saleId, null, "sale", saleDiscountMinor, optionalString(payload, "saleDiscountReason") ?? "Offline sale discount", discountApprovedByUserId);
  }
  for (const payment of payments) {
    await client.query(
      `
        INSERT INTO payments (
          id, organization_id, branch_id, sale_id, shift_id, payment_method,
          tendered_amount_minor, applied_amount_minor, change_amount_minor,
          reference, version, created_at, updated_at
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, 0, now(), now())
      `,
      [randomUUID(), command.organizationId, command.branchId, saleId, scope.shiftId, payment.method, payment.tenderedAmountMinor, payment.appliedAmountMinor, payment.changeAmountMinor, payment.reference],
    );
  }
  return {
    sale: {
      id: saleId,
      registerId: scope.registerId,
      shiftId: scope.shiftId,
      inventoryTransactionId,
      customerId,
      receiptNumber,
      status: "completed",
      completedAt: completedAt.toISOString(),
      version: 0,
    },
    inventory,
  };
}

export function validateSalePayload(payload: Record<string, unknown>): {
  lines: SaleLine[];
  payments: SalePayment[];
} {
  const lines = parseAndValidateLines(payload);
  const payments = parseAndValidatePayments(payload);
  validateHeader(payload, lines, payments);
  return {lines, payments};
}

async function validateSaleCatalog(
  client: PoolClient,
  command: AuthorizedCommand,
  lines: SaleLine[],
  completedAt: Date,
): Promise<void> {
  const products = await client.query<{
    id: string;
    sku: string;
    name: string;
    unit_name: string;
    unit_price_minor: string | null;
    tax_rate_basis_points: number;
    tax_inclusive: boolean;
  }>(
    `SELECT
       p.id,
       p.sku,
       p.name,
       u.name AS unit_name,
       COALESCE(branch_price.unit_price_minor, organization_price.unit_price_minor)::text
         AS unit_price_minor,
       COALESCE(tax.rate_basis_points, 0) AS tax_rate_basis_points,
       COALESCE(tax.is_inclusive, true) AS tax_inclusive
     FROM products p
     INNER JOIN units u
       ON u.id = p.unit_id AND u.organization_id = p.organization_id
       AND u.is_active = true AND u.deleted_at IS NULL
     LEFT JOIN tax_categories tax
       ON tax.id = p.tax_category_id AND tax.organization_id = p.organization_id
     LEFT JOIN LATERAL (
       SELECT price.unit_price_minor
       FROM product_prices price
       WHERE price.organization_id = p.organization_id
         AND price.product_id = p.id
         AND price.branch_id = $2
         AND price.effective_from <= $4
       ORDER BY price.effective_from DESC
       LIMIT 1
     ) branch_price ON true
     LEFT JOIN LATERAL (
       SELECT price.unit_price_minor
       FROM product_prices price
       WHERE price.organization_id = p.organization_id
         AND price.product_id = p.id
         AND price.branch_id IS NULL
         AND price.effective_from <= $4
       ORDER BY price.effective_from DESC
       LIMIT 1
     ) organization_price ON true
     WHERE p.organization_id = $1
       AND p.id = ANY($3::text[])
       AND p.is_active = true
       AND p.deleted_at IS NULL
       AND (p.tax_category_id IS NULL OR
         (tax.is_active = true AND tax.deleted_at IS NULL))`,
    [
      command.organizationId,
      command.branchId,
      lines.map((line) => line.productId),
      completedAt,
    ],
  );
  const byId = new Map(products.rows.map((product) => [product.id, product]));
  if (byId.size !== new Set(lines.map((line) => line.productId)).size) {
    throw new RemoteCommandError(
      "failed-precondition",
      "A sale product is unavailable in the active organization.",
    );
  }
  for (const line of lines) {
    const product = byId.get(line.productId)!;
    if (product.unit_price_minor === null ||
        Number(product.unit_price_minor) !== line.unitPriceMinor ||
        product.tax_rate_basis_points !== line.taxRateBasisPoints ||
        product.tax_inclusive !== line.taxInclusive) {
      throw new RemoteCommandError(
        "aborted",
        "A product price or tax changed. Refresh the sale and retry.",
      );
    }
    line.productName = product.name;
    line.sku = product.sku;
    line.unitName = product.unit_name;
  }
}

function parseAndValidateLines(payload: Record<string, unknown>): SaleLine[] {
  const lines = requiredArray(payload, "items").map((value, index) => {
    const item = asObject(value, `items[${index}]`);
    const quantityMilli = requiredInteger(item, "quantityMilli");
    const unitPriceMinor = requiredInteger(item, "unitPriceMinor");
    const unitCostMinor = requiredInteger(item, "unitCostMinor");
    const taxRateBasisPoints = requiredInteger(item, "taxRateBasisPoints");
    const taxInclusive = requiredBoolean(item, "taxInclusive");
    const discountAmountMinor = requiredInteger(item, "discountAmountMinor");
    if (quantityMilli <= 0 || unitPriceMinor < 0 || unitCostMinor < 0 ||
        taxRateBasisPoints < 0 || taxRateBasisPoints > 10000) {
      throw new RemoteCommandError("invalid-argument", "A sale line contains invalid values.");
    }
    const grossAmountMinor = roundDivide(unitPriceMinor * quantityMilli, 1000);
    if (discountAmountMinor < 0 || discountAmountMinor > grossAmountMinor) {
      throw new RemoteCommandError("invalid-argument", "A sale discount exceeds its line amount.");
    }
    const netAmountMinor = grossAmountMinor - discountAmountMinor;
    const taxAmountMinor = taxRateBasisPoints === 0 ? 0 : taxInclusive ?
      roundDivide(netAmountMinor * taxRateBasisPoints, 10000 + taxRateBasisPoints) :
      roundDivide(netAmountMinor * taxRateBasisPoints, 10000);
    const totalAmountMinor = taxInclusive ? netAmountMinor : netAmountMinor + taxAmountMinor;
    assertAmount(item, "grossAmountMinor", grossAmountMinor);
    assertAmount(item, "netAmountMinor", netAmountMinor, true);
    assertAmount(item, "taxAmountMinor", taxAmountMinor);
    assertAmount(item, "totalAmountMinor", totalAmountMinor);
    const itemDiscountMinor = optionalInteger(item, "itemDiscountMinor") ?? discountAmountMinor;
    const allocatedSaleDiscountMinor = optionalInteger(item, "allocatedSaleDiscountMinor") ??
      (discountAmountMinor - itemDiscountMinor);
    if (itemDiscountMinor < 0 || allocatedSaleDiscountMinor < 0 ||
        itemDiscountMinor + allocatedSaleDiscountMinor !== discountAmountMinor) {
      throw new RemoteCommandError("invalid-argument", "The line discount allocation is invalid.");
    }
    return {
      productId: requiredString(item, "productId"),
      stockLocationId: requiredString(item, "stockLocationId"),
      quantityMilli,
      unitPriceMinor,
      unitCostMinor,
      taxRateBasisPoints,
      taxInclusive,
      grossAmountMinor,
      discountAmountMinor,
      netAmountMinor,
      taxAmountMinor,
      totalAmountMinor,
      itemDiscountMinor,
      allocatedSaleDiscountMinor,
      itemDiscountReason: optionalString(item, "itemDiscountReason"),
      productName: optionalString(item, "productName"),
      sku: optionalString(item, "sku"),
      barcode: optionalString(item, "barcode"),
      unitName: optionalString(item, "unitName"),
    };
  });
  if (lines.length === 0) throw new RemoteCommandError("invalid-argument", "A sale requires at least one item.");
  const keys = lines.map((line) => `${line.stockLocationId}|${line.productId}`);
  if (new Set(keys).size !== keys.length) throw new RemoteCommandError("invalid-argument", "Sale products must be unique.");
  return lines;
}

function parseAndValidatePayments(payload: Record<string, unknown>): SalePayment[] {
  const methods = new Set<string>();
  const payments = requiredArray(payload, "payments").map((value, index) => {
    const payment = asObject(value, `payments[${index}]`);
    const method = requiredString(payment, "method");
    const tenderedAmountMinor = requiredInteger(payment, "tenderedAmountMinor");
    const appliedAmountMinor = requiredInteger(payment, "appliedAmountMinor");
    const changeAmountMinor = requiredInteger(payment, "changeAmountMinor");
    if (!methods.add(method) || !["cash", "card", "e_wallet"].includes(method) ||
        appliedAmountMinor <= 0 || tenderedAmountMinor !== appliedAmountMinor + changeAmountMinor ||
        (method !== "cash" && changeAmountMinor !== 0)) {
      throw new RemoteCommandError("invalid-argument", "Payment reconciliation is invalid.");
    }
    return {method, tenderedAmountMinor, appliedAmountMinor, changeAmountMinor, reference: optionalString(payment, "reference")};
  });
  if (payments.length === 0) throw new RemoteCommandError("invalid-argument", "A sale requires payment.");
  return payments;
}

function validateHeader(
  payload: Record<string, unknown>,
  lines: SaleLine[],
  payments: SalePayment[],
): void {
  const expected = {
    subtotalMinor: lines.reduce((total, line) => total + line.grossAmountMinor, 0),
    discountMinor: lines.reduce((total, line) => total + line.discountAmountMinor, 0),
    taxMinor: lines.reduce((total, line) => total + line.taxAmountMinor, 0),
    totalMinor: lines.reduce((total, line) => total + line.totalAmountMinor, 0),
    tenderedMinor: payments.reduce((total, payment) => total + payment.tenderedAmountMinor, 0),
    changeMinor: payments.reduce((total, payment) => total + payment.changeAmountMinor, 0),
  };
  for (const [field, amount] of Object.entries(expected)) assertAmount(payload, field, amount);
  const applied = payments.reduce((total, payment) => total + payment.appliedAmountMinor, 0);
  if (expected.totalMinor <= 0 || applied !== expected.totalMinor ||
      expected.tenderedMinor - applied !== expected.changeMinor) {
    throw new RemoteCommandError("invalid-argument", "Sale totals do not reconcile.");
  }
}

function assertAmount(
  payload: Record<string, unknown>,
  field: string,
  expected: number,
  optional = false,
): void {
  if (optional && payload[field] === undefined) return;
  if (requiredInteger(payload, field) !== expected) {
    throw new RemoteCommandError("invalid-argument", `${field} does not match the server calculation.`);
  }
}

async function loadCheckoutScope(
  client: PoolClient,
  command: AuthorizedCommand,
  deviceId: string,
): Promise<{
  registerId: string;
  registerCode: string;
  branchCode: string;
  shiftId: string | null;
  discountApprovalThresholdBasisPoints: number | null;
}> {
  const register = await client.query<{
    id: string;
    code: string;
    branch_code: string;
    allow_sales_without_open_shift: boolean;
    discount_approval_threshold_basis_points: number | null;
  }>(
    `
      SELECT r.id, r.code, b.code AS branch_code, b.allow_sales_without_open_shift,
             b.discount_approval_threshold_basis_points
      FROM registers r
      INNER JOIN branches b ON b.id = r.branch_id AND b.organization_id = r.organization_id
      INNER JOIN devices d ON d.id = r.assigned_device_id
        AND d.organization_id = r.organization_id
        AND d.branch_id = r.branch_id
        AND d.disabled_at IS NULL
      WHERE r.organization_id = $1 AND r.branch_id = $2
        AND r.assigned_device_id = $3 AND r.is_active = true AND r.deleted_at IS NULL
    `,
    [command.organizationId, command.branchId, deviceId],
  );
  if (register.rowCount !== 1) throw new RemoteCommandError("permission-denied", "The device is not assigned to an active register.");
  const row = register.rows[0];
  const shift = await client.query<{id: string}>(
    `SELECT id FROM shifts WHERE organization_id = $1 AND branch_id = $2
     AND register_id = $3 AND status = 'open' LIMIT 1`,
    [command.organizationId, command.branchId, row.id],
  );
  if (!row.allow_sales_without_open_shift && shift.rowCount !== 1) {
    throw new RemoteCommandError("failed-precondition", "An open shift is required for sales.");
  }
  return {
    registerId: row.id,
    registerCode: row.code,
    branchCode: row.branch_code,
    shiftId: shift.rows[0]?.id ?? null,
    discountApprovalThresholdBasisPoints: row.discount_approval_threshold_basis_points,
  };
}

async function allocateReceiptNumber(
  client: PoolClient,
  organizationId: string,
  branchId: string,
  registerId: string,
  branchCode: string,
  registerCode: string,
): Promise<string> {
  await client.query(
    "SELECT pg_advisory_xact_lock(hashtextextended($1, 0))",
    [`receipt|${organizationId}|${branchId}|${registerId}`],
  );
  let sequence = await client.query<{id: string; next_sequence: string}>(
    `SELECT id, next_sequence FROM receipt_sequences
     WHERE organization_id = $1 AND branch_id = $2 AND register_id = $3 FOR UPDATE`,
    [organizationId, branchId, registerId],
  );
  let value: number;
  if (sequence.rowCount === 0) {
    value = 1;
    await client.query(
      `INSERT INTO receipt_sequences (
        id, organization_id, branch_id, register_id, next_sequence,
        last_issued_at, version, created_at, updated_at
      ) VALUES ($1, $2, $3, $4, 2, now(), 1, now(), now())`,
      [randomUUID(), organizationId, branchId, registerId],
    );
  } else {
    value = Number(sequence.rows[0].next_sequence);
    await client.query(
      `UPDATE receipt_sequences SET next_sequence = next_sequence + 1,
       last_issued_at = now(), version = version + 1, updated_at = now() WHERE id = $1`,
      [sequence.rows[0].id],
    );
  }
  const normalizeCode = (text: string) => text.trim().toUpperCase().replace(/[^A-Z0-9]/g, "");
  return `${normalizeCode(branchCode)}-${normalizeCode(registerCode)}-${String(value).padStart(8, "0")}`;
}

async function loadProductSnapshot(
  client: PoolClient,
  organizationId: string,
  line: SaleLine,
): Promise<{name: string; sku: string; barcode: string | null; unitName: string}> {
  const result = await client.query<{name: string; sku: string; barcode: string | null; unit_name: string}>(
    `
      SELECT p.name, p.sku, u.name AS unit_name,
             (SELECT pb.barcode FROM product_barcodes pb
              WHERE pb.product_id = p.id AND pb.deleted_at IS NULL
              ORDER BY pb.is_primary DESC, pb.created_at LIMIT 1) AS barcode
      FROM products p
      INNER JOIN units u ON u.id = p.unit_id AND u.organization_id = p.organization_id
      WHERE p.id = $1 AND p.organization_id = $2
    `,
    [line.productId, organizationId],
  );
  if (result.rowCount !== 1) throw new RemoteCommandError("invalid-argument", "A sale product is unavailable.");
  const remote = result.rows[0];
  return {
    name: line.productName ?? remote.name,
    sku: line.sku ?? remote.sku,
    barcode: line.barcode ?? remote.barcode,
    unitName: line.unitName ?? remote.unit_name,
  };
}

async function insertDiscount(
  client: PoolClient,
  command: AuthorizedCommand,
  saleId: string,
  saleItemId: string | null,
  scope: "item" | "sale",
  amountMinor: number,
  reason: string,
  approvedByUserId: string | null,
): Promise<void> {
  await client.query(
    `INSERT INTO sale_discounts (
      id, organization_id, branch_id, sale_id, sale_item_id,
      discount_scope, discount_type, amount_minor, reason,
      approved_by_user_id, approved_at, version, created_at, updated_at
    ) VALUES ($1, $2, $3, $4, $5, $6, 'fixed_amount', $7, $8, $9,
      CASE WHEN $9::text IS NULL THEN NULL ELSE now() END, 0, now(), now())`,
    [randomUUID(), command.organizationId, command.branchId, saleId, saleItemId, scope, amountMinor, reason, approvedByUserId],
  );
}
