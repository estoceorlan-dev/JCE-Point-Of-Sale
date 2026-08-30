import assert from "node:assert/strict";
import test from "node:test";
import {PoolClient} from "pg";

import {AuthorizedCommand, RemoteCommandError} from "./command_types";
import {correctSale} from "./sale_correction_commands";

type FakeOptions = {
  priorQuantityMilli?: number;
  approvalThresholdMinor?: number | null;
};

class FakeCorrectionClient {
  constructor(private readonly options: FakeOptions = {}) {}

  readonly statements: string[] = [];

  async query(text: string): Promise<unknown> {
    const normalized = text.replace(/\s+/g, " ").trim();
    this.statements.push(normalized);
    if (normalized.includes("FROM sales") && normalized.includes("FOR UPDATE")) {
      return result([{
        id: "sale-1",
        status: "completed",
        completed_at: new Date(),
      }]);
    }
    if (normalized.includes("FROM sale_items")) {
      return result([{
        id: "sale-item-1",
        line_number: 1,
        product_id: "product-1",
        quantity_milli: "2000",
        gross_amount_minor: "201",
        discount_amount_minor: "1",
        tax_amount_minor: "0",
        total_amount_minor: "200",
      }]);
    }
    if (normalized.includes("FROM sale_return_items")) {
      const quantity = this.options.priorQuantityMilli ?? 0;
      return quantity === 0 ? result([]) : result([{
        sale_item_id: "sale-item-1",
        quantity_milli: String(quantity),
        subtotal_minor: "101",
        discount_minor: "1",
        tax_minor: "0",
        total_minor: "100",
      }]);
    }
    if (normalized.includes("FROM branches")) {
      const threshold = this.options.approvalThresholdMinor;
      return result([{
        return_approval_threshold_minor:
          threshold === undefined || threshold === null ? null : String(threshold),
        void_window_minutes: 15,
      }]);
    }
    if (normalized.startsWith("INSERT INTO sale_returns") ||
        normalized.startsWith("INSERT INTO sale_return_items") ||
        normalized.startsWith("INSERT INTO refund_payments")) {
      return result([]);
    }
    throw new Error(`Unexpected fake query: ${normalized}`);
  }
}

function result(rows: Record<string, unknown>[]) {
  return {rows, rowCount: rows.length};
}

function command(
  payloadOverrides: Record<string, unknown> = {},
  permissionCodes = ["sales.returns.process"],
): AuthorizedCommand {
  return {
    firebaseUid: "firebase-user-1",
    actorUserId: "user-1",
    permissions: new Set(permissionCodes),
    operationId: "return-operation-1",
    organizationId: "organization-1",
    branchId: "branch-1",
    commandType: "sale.return",
    aggregateType: "sale_return",
    aggregateId: "return-1",
    payload: {
      id: "return-1",
      saleId: "sale-1",
      returnNumber: "RET-0001",
      correctionType: "return",
      reasonCode: "CUSTOMER_RETURN",
      notes: null,
      subtotalMinor: 101,
      discountMinor: 1,
      taxMinor: 0,
      totalMinor: 100,
      items: [{
        lineNumber: 1,
        productId: "product-1",
        quantityMilli: 1000,
        disposition: "non_restock",
        destinationStockLocationId: null,
        subtotalMinor: 101,
        discountMinor: 1,
        taxMinor: 0,
        totalMinor: 100,
      }],
      refunds: [{
        method: "e_wallet",
        amountMinor: 100,
        reference: "wallet-ref-1",
      }],
      completedAt: new Date().toISOString(),
      ...payloadOverrides,
    },
  };
}

function asClient(client: FakeCorrectionClient): PoolClient {
  return client as unknown as PoolClient;
}

test("the server rejects quantities above the remaining sold quantity", async () => {
  const client = new FakeCorrectionClient({priorQuantityMilli: 1000});
  await assert.rejects(
    correctSale(asClient(client), command({
      items: [{
        lineNumber: 1,
        productId: "product-1",
        quantityMilli: 1500,
        disposition: "non_restock",
        destinationStockLocationId: null,
        subtotalMinor: 151,
        discountMinor: 1,
        taxMinor: 0,
        totalMinor: 150,
      }],
      subtotalMinor: 151,
      discountMinor: 1,
      totalMinor: 150,
      refunds: [{method: "e_wallet", amountMinor: 150}],
    })),
    (error) => error instanceof RemoteCommandError &&
      error.code === "failed-precondition",
  );
  assert.equal(client.statements.some((sql) => sql.startsWith("INSERT")), false);
});

test("the server rejects refund totals that do not reconcile", async () => {
  const client = new FakeCorrectionClient();
  await assert.rejects(
    correctSale(asClient(client), command({
      refunds: [{method: "e_wallet", amountMinor: 99}],
    })),
    (error) => error instanceof RemoteCommandError &&
      error.code === "invalid-argument",
  );
  assert.equal(client.statements.some((sql) => sql.startsWith("INSERT")), false);
});

test("configured thresholds require an authorized manager", async () => {
  const client = new FakeCorrectionClient({approvalThresholdMinor: 50});
  await assert.rejects(
    correctSale(asClient(client), command()),
    (error) => error instanceof RemoteCommandError &&
      error.code === "permission-denied",
  );
  assert.equal(client.statements.some((sql) => sql.startsWith("INSERT")), false);
});

test("a valid return inserts compensating records without mutating the sale", async () => {
  const client = new FakeCorrectionClient();
  const response = await correctSale(asClient(client), command());

  assert.equal(
    (response.correction as Record<string, unknown>).status,
    "completed",
  );
  assert.equal(
    client.statements.some((sql) => sql.startsWith("INSERT INTO sale_returns")),
    true,
  );
  assert.equal(
    client.statements.some((sql) =>
      /^(UPDATE|DELETE FROM) sales\b/.test(sql) ||
      /^(UPDATE|DELETE FROM) sale_items\b/.test(sql)),
    false,
  );
});
