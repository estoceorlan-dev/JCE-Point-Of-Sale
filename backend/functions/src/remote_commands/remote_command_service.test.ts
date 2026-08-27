import assert from "node:assert/strict";
import test from "node:test";
import {PoolClient} from "pg";

import {RemoteCommandError, RemoteCommandInput} from "./command_types";
import {processRemoteCommand} from "./remote_command_service";
import {validateSalePayload} from "./sale_commands";

type FakeOptions = {
  access?: boolean;
  priorResult?: Record<string, unknown>;
  failAudit?: boolean;
};

class FakePoolClient {
  constructor(private readonly options: FakeOptions = {}) {}

  readonly statements: string[] = [];
  pendingBranchWrite = false;
  committedBranchWrite = false;

  async query(text: string): Promise<unknown> {
    const normalized = text.replace(/\s+/g, " ").trim();
    this.statements.push(normalized);
    if (normalized === "BEGIN" || normalized.startsWith("SELECT pg_advisory_xact_lock")) {
      return result([]);
    }
    if (normalized === "ROLLBACK") {
      this.pendingBranchWrite = false;
      return result([]);
    }
    if (normalized === "COMMIT") {
      this.committedBranchWrite = this.pendingBranchWrite;
      return result([]);
    }
    if (normalized.includes("SELECT au.id AS actor_user_id")) {
      return this.options.access === false ? result([]) : result([{
        actor_user_id: "user-1",
        permission_codes: [
          "products.manage",
          "inventory.manage",
          "registers.manage",
          "sales.process",
          "settings.manage",
        ],
      }]);
    }
    if (normalized.includes("FROM processed_operations")) {
      return this.options.priorResult === undefined ? result([]) : result([{
        command_type: "inventory.transaction.post",
        aggregate_type: "inventory_transaction",
        aggregate_id: "movement-1",
        result_json: this.options.priorResult,
      }]);
    }
    if (normalized.startsWith("UPDATE branches SET") &&
        normalized.includes("discount_approval_threshold_basis_points")) {
      this.pendingBranchWrite = true;
      return result([{id: "branch-1", version: 4}]);
    }
    if (normalized.startsWith("INSERT INTO audit_logs")) {
      if (this.options.failAudit === true) throw new Error("audit unavailable");
      return result([]);
    }
    if (normalized.startsWith("INSERT INTO change_feed") ||
        normalized.startsWith("INSERT INTO processed_operations")) {
      return result([]);
    }
    throw new Error(`Unexpected fake query: ${normalized}`);
  }
}

function result(rows: Record<string, unknown>[]) {
  return {rows, rowCount: rows.length};
}

function command(overrides: Partial<RemoteCommandInput> = {}): RemoteCommandInput {
  return {
    firebaseUid: "firebase-user-1",
    operationId: "operation-1",
    organizationId: "organization-1",
    branchId: "branch-1",
    commandType: "inventory.transaction.post",
    aggregateType: "inventory_transaction",
    aggregateId: "movement-1",
    payload: {},
    ...overrides,
  };
}

function asClient(client: FakePoolClient): PoolClient {
  return client as unknown as PoolClient;
}

test("cross-organization access is denied before a remote write", async () => {
  const client = new FakePoolClient({access: false});
  await assert.rejects(
    processRemoteCommand(asClient(client), command({organizationId: "other-org"})),
    (error) => error instanceof RemoteCommandError && error.code === "permission-denied",
  );
  assert.equal(client.statements.at(-1), "ROLLBACK");
  assert.equal(client.statements.some((sql) => sql.startsWith("INSERT INTO")), false);
});

test("cross-branch access is denied before a remote write", async () => {
  const client = new FakePoolClient({access: false});
  await assert.rejects(
    processRemoteCommand(asClient(client), command({branchId: "other-branch"})),
    (error) => error instanceof RemoteCommandError && error.code === "permission-denied",
  );
  assert.equal(client.statements.at(-1), "ROLLBACK");
});

test("a duplicate operation returns its original result", async () => {
  const original = {transactionId: "movement-1", balances: [{onHandMilli: 7}]};
  const client = new FakePoolClient({priorResult: original});
  const execution = await processRemoteCommand(asClient(client), command());
  assert.deepEqual(execution, {
    operationId: "operation-1",
    duplicate: true,
    result: original,
  });
  assert.equal(client.statements.at(-1), "COMMIT");
  assert.equal(client.statements.some((sql) => sql.includes("inventory_balances")), false);
});

test("an audit failure rolls the entire command transaction back", async () => {
  const client = new FakePoolClient({failAudit: true});
  await assert.rejects(
    processRemoteCommand(asClient(client), command({
      commandType: "branch.discount_policy.update",
      aggregateType: "branch",
      aggregateId: "branch-1",
      payload: {approvalThresholdBasisPoints: 1500},
    })),
    /audit unavailable/,
  );
  assert.equal(client.statements.at(-1), "ROLLBACK");
  assert.equal(client.pendingBranchWrite, false);
  assert.equal(client.committedBranchWrite, false);
});

test("sale totals are recalculated and tampering is rejected", () => {
  assert.throws(
    () => validateSalePayload({
      items: [{
        productId: "product-1",
        stockLocationId: "location-1",
        quantityMilli: 1000,
        unitPriceMinor: 100,
        unitCostMinor: 60,
        taxRateBasisPoints: 0,
        taxInclusive: true,
        grossAmountMinor: 100,
        discountAmountMinor: 0,
        netAmountMinor: 100,
        taxAmountMinor: 0,
        totalAmountMinor: 100,
      }],
      payments: [{
        method: "cash",
        tenderedAmountMinor: 100,
        appliedAmountMinor: 100,
        changeAmountMinor: 0,
      }],
      subtotalMinor: 100,
      discountMinor: 0,
      taxMinor: 0,
      totalMinor: 99,
      tenderedMinor: 100,
      changeMinor: 0,
    }),
    (error) => error instanceof RemoteCommandError && error.code === "invalid-argument",
  );
});

test("retrying a stock operation cannot apply its balance twice", async () => {
  const original = {transactionId: "movement-1", balances: [{onHandMilli: 12, version: 1}]};
  for (let retry = 0; retry < 2; retry += 1) {
    const client = new FakePoolClient({priorResult: original});
    const execution = await processRemoteCommand(asClient(client), command());
    assert.equal(execution.duplicate, true);
    assert.deepEqual(execution.result, original);
    assert.equal(client.statements.some((sql) => sql.includes("inventory_balances")), false);
  }
});
