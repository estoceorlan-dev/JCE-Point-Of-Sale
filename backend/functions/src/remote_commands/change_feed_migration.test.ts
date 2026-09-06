import assert from "node:assert/strict";
import {readFile} from "node:fs/promises";
import path from "node:path";
import test from "node:test";

test("feed constraint accepts current tombstones and preserves legacy event types", async () => {
  const sql = await readFile(path.resolve(__dirname,
    "../../../sql/migrations/0012_change_feed_tombstones.sql"), "utf8");
  assert.match(sql, /CHECK\s*\(change_type\s+IN\s*\('upsert',\s*'delete',\s*'tombstone'\)\)/i);
  assert.doesNotMatch(sql, /\b(?:UPDATE|DELETE\s+FROM|TRUNCATE)\s+change_feed\b/i);
});
