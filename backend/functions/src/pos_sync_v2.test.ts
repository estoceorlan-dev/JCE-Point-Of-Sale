import assert from "node:assert/strict";
import {readFile} from "node:fs/promises";
import path from "node:path";
import test from "node:test";
import type {PoolClient} from "pg";

import {getPosBootstrapPageForUser} from "./pos_bootstrap.js";
import {pullAuthorizedChangesForUser} from "./pull_authorized_changes.js";

const migrationPath = path.resolve(
  __dirname,
  "../../sql/migrations/0014_pos_sync_v2.sql",
);

test("POS sync migration installs installation-owned claims and receipt aliases", async () => {
  const sql = await readFile(migrationPath, "utf8");
  assert.match(sql, /'registers\.claim'/);
  assert.match(sql, /WHERE\s+rp\.permission_code\s*=\s*'sales\.process'/i);
  assert.match(
    sql,
    /INSERT INTO role_permissions\s*\(role_id, permission_code, granted_at\)/i,
  );
  assert.match(sql, /ALTER\s+COLUMN\s+user_id\s+DROP\s+NOT\s+NULL/i);
  assert.match(sql, /register_claims_active_device_uidx/i);
  assert.match(sql, /register_claims_active_register_uidx/i);
  assert.match(sql, /duplicate active register assignments must be repaired/i);
  assert.match(sql, /CREATE\s+TABLE\s+IF\s+NOT\s+EXISTS\s+sale_receipt_aliases/i);
  assert.match(sql, /consumed_by_operation_id/i);
  assert.doesNotMatch(
    sql,
    /product_prices_snapshot_page_idx[\s\S]{0,150}WHERE\s+deleted_at/i,
  );
});

test("authorized pulls advance past unreadable changes without exposing them", async () => {
  let queryNumber = 0;
  const client = {
    query: async () => {
      queryNumber += 1;
      if (queryNumber === 1) {
        return {
          rowCount: 1,
          rows: [{permission_codes: ["sales.process"]}],
        };
      }
      return {
        rowCount: 2,
        rows: [
          {
            sequence: "10",
            organization_id: "organization",
            branch_id: "branch",
            aggregate_type: "app_user",
            aggregate_id: "private-user",
            operation_id: "private-operation",
            change_type: "upsert",
            version: 1,
            payload_json: {secret: true},
            occurred_at: new Date("2026-09-10T08:00:00.000Z"),
          },
          {
            sequence: "11",
            organization_id: "organization",
            branch_id: "branch",
            aggregate_type: "product",
            aggregate_id: "product",
            operation_id: "product-operation",
            change_type: "upsert",
            version: 2,
            payload_json: {schemaVersion: 1},
            occurred_at: new Date("2026-09-10T08:00:01.000Z"),
          },
        ],
      };
    },
  } as unknown as PoolClient;

  const page = await pullAuthorizedChangesForUser(client, {
    firebaseUid: "firebase-cashier",
    organizationId: "organization",
    branchId: "branch",
    afterSequence: 9,
    limit: 100,
    projection: "pos",
  });

  assert.equal(page.nextCursor, 11);
  assert.equal(page.hasMore, false);
  assert.deepEqual(
    (page.changes as Array<{aggregateId: string}>).map(
      (change) => change.aggregateId,
    ),
    ["product"],
  );
  assert.doesNotMatch(JSON.stringify(page), /private-user|secret/);
});

test("organization bootstrap pages use contiguous typed parameters", async () => {
  const pageQuery = await captureBootstrapPageQuery("organization");

  assert.match(pageQuery.text, /t\.id = \$1/);
  assert.match(
    pageQuery.text,
    /\(\$2::text IS NULL OR t\.id > \$2::text\)/,
  );
  assert.match(pageQuery.text, /t\.updated_at <= \$3::timestamptz/);
  assert.match(pageQuery.text, /LIMIT \$4::integer/);
  assert.deepEqual(pageQuery.values.slice(0, 2), [organizationId, null]);
  assert.equal(pageQuery.values.length, 4);
});

test("branch bootstrap pages retain their branch scope before paging parameters", async () => {
  const pageQuery = await captureBootstrapPageQuery("registers");

  assert.match(pageQuery.text, /t\.organization_id = \$1/);
  assert.match(pageQuery.text, /t\.branch_id = \$2/);
  assert.match(
    pageQuery.text,
    /\(\$3::text IS NULL OR t\.id > \$3::text\)/,
  );
  assert.match(pageQuery.text, /t\.updated_at <= \$4::timestamptz/);
  assert.match(pageQuery.text, /LIMIT \$5::integer/);
  assert.deepEqual(pageQuery.values.slice(0, 3), [
    organizationId,
    branchId,
    null,
  ]);
  assert.equal(pageQuery.values.length, 5);
});

const organizationId = "11111111-1111-4111-8111-111111111111";
const branchId = "22222222-2222-4222-8222-222222222222";

async function captureBootstrapPageQuery(collection: string): Promise<{
  text: string;
  values: readonly unknown[];
}> {
  const captured: Array<{text: string; values: readonly unknown[]}> = [];
  const client = {
    query: async (text: string, values: readonly unknown[] = []) => {
      if (text.includes("FROM app_users")) {
        return {rowCount: 1, rows: [{exists: 1}]};
      }
      if (text.includes("FROM change_feed")) {
        return {rowCount: 1, rows: [{watermark: "0"}]};
      }
      captured.push({text, values});
      return {rowCount: 0, rows: []};
    },
  } as unknown as PoolClient;

  await getPosBootstrapPageForUser(client, {
    firebaseUid: "firebase-user",
    organizationId,
    branchId,
    collection,
  });

  assert.equal(captured.length, 1);
  return captured[0];
}
