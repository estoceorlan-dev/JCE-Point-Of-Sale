import assert from "node:assert/strict";
import {readFile} from "node:fs/promises";
import path from "node:path";
import test from "node:test";

const migrationPath = path.resolve(__dirname, "../../../sql/migrations/0011_admin_operations.sql");

test("administration migration seeds stable permissions without assigning access", async () => {
  const sql = (await readFile(migrationPath, "utf8")).replace(/--[^\n]*/g, "");
  assert.match(sql, /INSERT\s+INTO\s+permissions\b/i);
  assert.match(sql, /'branches\.manage'/);
  assert.match(sql, /'roles\.manage'/);
  const statements = sql.replace(/'(?:''|[^'])*'/g, "''");
  assert.doesNotMatch(statements, /\b(role_permissions|user_role_assignments|roles)\b/i);
});

test("administration migration retains normalized branch-code uniqueness", async () => {
  const sql = await readFile(migrationPath, "utf8");
  assert.match(sql, /CREATE\s+UNIQUE\s+INDEX\s+IF\s+NOT\s+EXISTS\s+branches_normalized_code_unique/i);
  assert.match(sql, /ON\s+branches\s*\(organization_id,\s*upper\(btrim\(code\)\)\)/i);
});
