import assert from "node:assert/strict";
import {readFile} from "node:fs/promises";
import path from "node:path";
import test from "node:test";
import type {PoolClient} from "pg";

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
