import assert from "node:assert/strict";
import test from "node:test";
import {PoolClient} from "pg";

import {AuthorizedCommand, RemoteCommandError} from "./command_types";
import {applyStockLocationCommand} from "./stock_location_commands";

type LocationRow = Record<string, unknown>;

type FakeOptions = {
  current?: LocationRow;
  activeCount?: number;
  hasStock?: boolean;
  hasCount?: boolean;
  hasTransfer?: boolean;
};

class FakePoolClient {
  constructor(private readonly options: FakeOptions = {}) {}

  readonly statements: string[] = [];
  readonly values: unknown[][] = [];

  async query(
    text: string,
    values?: unknown[],
  ): Promise<{rows: LocationRow[]; rowCount: number}> {
    const sql = text.replace(/\s+/g, " ").trim();
    this.statements.push(sql);
    this.values.push(values ?? []);
    if (sql.startsWith("SELECT pg_advisory_xact_lock")) return result([]);
    if (sql.startsWith("SELECT * FROM stock_locations") && sql.includes("FOR UPDATE")) {
      return result(this.options.current === undefined ? [] : [this.options.current]);
    }
    if (sql.startsWith("SELECT id FROM stock_locations")) return result([]);
    if (sql.startsWith("UPDATE stock_locations SET is_default")) {
      return result([{...location("previous-default"), is_default: false, version: 3}]);
    }
    if (sql.startsWith("INSERT INTO stock_locations")) {
      return result([{...location("location-2"), code: "BACK_ROOM", is_default: true, version: 0}]);
    }
    if (sql.includes("AS active_count")) {
      return result([{
        active_count: this.options.activeCount ?? 2,
        has_stock: this.options.hasStock ?? false,
      }]);
    }
    if (sql.includes("AS has_count")) {
      return result([{
        has_count: this.options.hasCount ?? false,
        has_transfer: this.options.hasTransfer ?? false,
      }]);
    }
    if (sql.startsWith("UPDATE stock_locations SET is_active")) {
      return result([{
        ...this.options.current!,
        is_active: false,
        deleted_at: new Date(),
        version: 3,
      }]);
    }
    throw new Error(`Unexpected query: ${sql}`);
  }
}

function location(id = "location-1"): LocationRow {
  return {
    id,
    organization_id: "organization-1",
    branch_id: "branch-1",
    code: "WAREHOUSE",
    name: "Warehouse",
    location_type: "warehouse",
    is_default: false,
    is_active: true,
    deleted_at: null,
    version: 2,
  };
}

function result(rows: LocationRow[]) {
  return {rows, rowCount: rows.length};
}

function command(overrides: Partial<AuthorizedCommand> = {}): AuthorizedCommand {
  return {
    firebaseUid: "firebase-1",
    actorUserId: "user-1",
    permissions: new Set(["inventory.manage"]),
    operationId: "operation-1",
    organizationId: "organization-1",
    branchId: "branch-1",
    commandType: "stock_location.create",
    aggregateType: "stock_location",
    aggregateId: "location-2",
    payload: {
      id: "location-2",
      code: "back room",
      name: "Back room",
      locationType: "warehouse",
      isDefault: true,
    },
    ...overrides,
  };
}

function asClient(client: FakePoolClient): PoolClient {
  return client as unknown as PoolClient;
}

test("creation normalizes the code and returns every default projection", async () => {
  const client = new FakePoolClient();
  const saved = await applyStockLocationCommand(asClient(client), command());

  assert.equal((saved.stockLocation as LocationRow).code, "BACK_ROOM");
  assert.equal((saved.demotedLocations as LocationRow[]).length, 1);
  assert.match(client.statements[0], /pg_advisory_xact_lock/);
  assert.deepEqual(client.values[1], ["organization-1", "branch-1", "BACK_ROOM", "location-2"]);
});

test("stale edits reject before a remote location write", async () => {
  const client = new FakePoolClient({current: location()});
  await assert.rejects(
    applyStockLocationCommand(asClient(client), command({
      commandType: "stock_location.update",
      aggregateId: "location-1",
      payload: {...command().payload, id: "location-1", expectedVersion: 1},
    })),
    (error) => error instanceof RemoteCommandError && error.code === "aborted",
  );
  assert.equal(client.statements.some((sql) => sql.startsWith("UPDATE stock_locations SET code")), false);
});

test("archive rejects a nonzero balance before changing the location", async () => {
  const client = new FakePoolClient({current: location(), hasStock: true});
  await assert.rejects(
    applyStockLocationCommand(asClient(client), command({
      commandType: "stock_location.archive",
      aggregateId: "location-1",
      payload: {expectedVersion: 2},
    })),
    (error) => error instanceof RemoteCommandError && error.code === "failed-precondition",
  );
  assert.equal(client.statements.some((sql) => sql.startsWith("UPDATE stock_locations SET is_active")), false);
});

test("archive locks, checks active work, and returns an archived projection", async () => {
  const client = new FakePoolClient({current: location()});
  const saved = await applyStockLocationCommand(asClient(client), command({
    commandType: "stock_location.archive",
    aggregateId: "location-1",
    payload: {expectedVersion: 2},
  }));

  assert.equal((saved.stockLocation as LocationRow).is_active, false);
  assert.ok(client.statements.some((sql) => sql.includes("FROM stock_counts")));
  assert.ok(client.statements.some((sql) => sql.startsWith("UPDATE stock_locations SET is_active")));
});
