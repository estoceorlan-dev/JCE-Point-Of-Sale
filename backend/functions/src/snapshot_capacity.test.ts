import assert from "node:assert/strict";
import test from "node:test";
import {boundedSnapshotQuery, ensureSnapshotFits, SnapshotCapacityError} from "./snapshot_capacity";

test("snapshot query fetches only the configured bound plus a truncation sentinel", async () => {
  const rows = [{id: "synthetic"}];
  const client = {async query(sql: string, values: unknown[]) {
    assert.equal(sql, "SELECT id FROM branches WHERE organization_id = $1 LIMIT $2");
    assert.deepEqual(values, ["org", 5001]);
    return {rows};
  }};
  assert.deepEqual((await boundedSnapshotQuery(client as never,
    "SELECT id FROM branches WHERE organization_id = $1", ["org"])).rows, rows);
});

test("oversized snapshots reject instead of replacing a local cache with partial data", async () => {
  const client = {async query() {return {rows: Array(5001).fill({id: "test"})};}};
  await assert.rejects(boundedSnapshotQuery(client as never, "SELECT id FROM branches", []),
    SnapshotCapacityError);
  assert.throws(() => ensureSnapshotFits({large: "x".repeat(2 * 1024 * 1024)}), SnapshotCapacityError);
  assert.deepEqual(ensureSnapshotFits({rows: []}), {rows: []});
});
