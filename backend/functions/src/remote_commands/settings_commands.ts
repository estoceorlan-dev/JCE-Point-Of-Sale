import {PoolClient} from "pg";

import {
  AuthorizedCommand,
  CommandResult,
  RemoteCommandError,
  asObject,
  optionalInteger,
  optionalString,
  requiredBoolean,
  requiredInteger,
  requiredString,
} from "./command_types";

type SettingRow = {
  id: string;
  settingKey: string;
  value: unknown;
  version: number;
  createdAt: Date;
};

const settingKeys = new Set([
  "tax.behavior",
  "inventory.allow_negative_stock",
  "inventory.adjustment_approval_threshold_milli",
  "receipt.header",
  "receipt.footer",
  "receipt.show_tax_breakdown",
  "receipt.paper_width_characters",
  "sales.discount_limit_basis_points",
  "sales.discount_approval_threshold_basis_points",
  "sales.require_non_cash_reference",
  "shifts.allow_multiple_open_per_user",
  "shifts.allow_sales_without_open_shift",
  "shifts.cash_discrepancy_approval_threshold_minor",
  "returns.approval_threshold_minor",
  "returns.void_window_minutes",
  "transfers.approval_threshold_milli",
]);

export async function applySettingsCommand(
  client: PoolClient,
  command: AuthorizedCommand,
): Promise<CommandResult> {
  switch (command.commandType) {
  case "setting.organization.upsert":
    return upsertSetting(client, command, false);
  case "setting.branch.upsert":
    return upsertSetting(client, command, true);
  case "setting.branch.delete":
    return deleteBranchSetting(client, command);
  case "reason_code.upsert":
    return upsertReasonCode(client, command);
  case "feature_flag.upsert":
    return upsertFeatureFlag(client, command);
  default:
    throw new RemoteCommandError(
      "invalid-argument",
      `Unsupported settings command: ${command.commandType}.`,
    );
  }
}

async function upsertSetting(
  client: PoolClient,
  command: AuthorizedCommand,
  branchScoped: boolean,
): Promise<CommandResult> {
  const id = matchingId(command);
  const key = requiredString(command.payload, "key");
  if (!settingKeys.has(key)) {
    throw new RemoteCommandError("invalid-argument", "The setting key is not supported.");
  }
  const value = command.payload.value;
  validateSetting(key, value);
  const table = branchScoped ? "branch_settings" : "organization_settings";
  const existing = await client.query<SettingRow>(
    `SELECT id, setting_key AS "settingKey", value_json AS value,
            version, created_at AS "createdAt"
     FROM ${table} WHERE id = $1 AND organization_id = $2 FOR UPDATE`,
    [id, command.organizationId],
  );
  const before = existing.rows[0] ?? null;
  const expectedVersion = optionalInteger(command.payload, "expectedVersion");
  if (before === null) {
    if (branchScoped) {
      await client.query(
        `INSERT INTO branch_settings (
           id, organization_id, branch_id, setting_key, value_json, version,
           updated_by_user_id, created_at, updated_at
         ) VALUES ($1, $2, $3, $4, $5::jsonb, 0, $6, now(), now())`,
        [id, command.organizationId, command.branchId, key,
          JSON.stringify(value), command.actorUserId],
      );
    } else {
      await client.query(
        `INSERT INTO organization_settings (
           id, organization_id, setting_key, value_json, version,
           updated_by_user_id, created_at, updated_at
         ) VALUES ($1, $2, $3, $4::jsonb, 0, $5, now(), now())`,
        [id, command.organizationId, key, JSON.stringify(value), command.actorUserId],
      );
    }
  } else {
    if (before.settingKey !== key ||
        (expectedVersion !== null && before.version !== expectedVersion)) {
      throw changedSetting();
    }
    const updated = await client.query(
      `UPDATE ${table} SET value_json = $3::jsonb, version = version + 1,
         updated_by_user_id = $4, updated_at = now()
       WHERE id = $1 AND organization_id = $2 AND version = $5`,
      [id, command.organizationId, JSON.stringify(value), command.actorUserId,
        before.version],
    );
    if (updated.rowCount !== 1) throw changedSetting();
  }
  await updateBranchProjection(client, command, key, value, branchScoped);
  return {
    setting: await settingResult(client, command, id, branchScoped),
    before: before === null ? null : settingAuditValue(before),
  };
}

async function deleteBranchSetting(
  client: PoolClient,
  command: AuthorizedCommand,
): Promise<CommandResult> {
  const id = matchingId(command);
  const key = requiredString(command.payload, "key");
  if (!settingKeys.has(key)) {
    throw new RemoteCommandError("invalid-argument", "The setting key is not supported.");
  }
  const existing = await client.query<SettingRow>(
    `SELECT id, setting_key AS "settingKey", value_json AS value,
            version, created_at AS "createdAt"
     FROM branch_settings
     WHERE id = $1 AND organization_id = $2 AND branch_id = $3 FOR UPDATE`,
    [id, command.organizationId, command.branchId],
  );
  if (existing.rowCount === 0) {
    return {deleted: {id, version: 0}, before: null};
  }
  const row = existing.rows[0];
  const expectedVersion = optionalInteger(command.payload, "expectedVersion");
  if (row.settingKey !== key ||
      (expectedVersion !== null && expectedVersion !== row.version)) {
    throw changedSetting();
  }
  await client.query(
    "DELETE FROM branch_settings WHERE id = $1 AND organization_id = $2 AND branch_id = $3",
    [id, command.organizationId, command.branchId],
  );
  const inherited = await organizationSettingValue(client, command.organizationId, key);
  await updateBranchProjection(
    client,
    command,
    key,
    inherited ?? defaultSettingValue(key),
    true,
  );
  return {
    deleted: {id, version: row.version + 1},
    before: settingAuditValue(row),
  };
}

async function upsertReasonCode(
  client: PoolClient,
  command: AuthorizedCommand,
): Promise<CommandResult> {
  const id = matchingId(command);
  const branchId = optionalString(command.payload, "branchId");
  requireBranchScope(command, branchId);
  const category = requiredString(command.payload, "category");
  const code = requiredString(command.payload, "code");
  const label = requiredString(command.payload, "label");
  const requiresNote = requiredBoolean(command.payload, "requiresNote");
  const isActive = requiredBoolean(command.payload, "isActive");
  const sortOrder = requiredInteger(command.payload, "sortOrder");
  if (!new Set(["inventory_adjustment", "stock_count_variance", "sale_return",
    "cash_movement", "transfer_discrepancy"]).has(category) ||
      !/^[A-Z0-9_]{2,40}$/.test(code) || label.length > 80) {
    throw new RemoteCommandError("invalid-argument", "The reason code is invalid.");
  }
  const existing = await client.query<Record<string, unknown>>(
    `SELECT id, category, code, label, requires_note AS "requiresNote",
            is_active AS "isActive", sort_order AS "sortOrder", version,
            branch_id AS "branchId"
     FROM reason_codes WHERE id = $1 AND organization_id = $2 FOR UPDATE`,
    [id, command.organizationId],
  );
  const before = existing.rows[0] ?? null;
  const expectedVersion = optionalInteger(command.payload, "expectedVersion");
  if (before === null) {
    await client.query(
      `INSERT INTO reason_codes (
         id, organization_id, branch_id, branch_scope, category, code, label,
         requires_note, is_active, sort_order, version, created_at, updated_at
       ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, 0, now(), now())`,
      [id, command.organizationId, branchId, branchId ?? "*", category, code,
        label, requiresNote, isActive, sortOrder],
    );
  } else {
    if (expectedVersion !== null && before.version !== expectedVersion) {
      throw changedSetting();
    }
    const changed = await client.query(
      `UPDATE reason_codes SET label = $3, requires_note = $4,
         is_active = $5, sort_order = $6, version = version + 1,
         updated_at = now()
       WHERE id = $1 AND organization_id = $2 AND version = $7`,
      [id, command.organizationId, label, requiresNote, isActive, sortOrder,
        before.version],
    );
    if (changed.rowCount !== 1) throw changedSetting();
  }
  const result = await client.query(
    `SELECT id, branch_id AS "branchId", category, code, label,
            requires_note AS "requiresNote", is_active AS "isActive",
            sort_order AS "sortOrder", version,
            created_at AS "createdAt", updated_at AS "updatedAt"
     FROM reason_codes WHERE id = $1 AND organization_id = $2`,
    [id, command.organizationId],
  );
  return {reasonCode: result.rows[0], before};
}

async function upsertFeatureFlag(
  client: PoolClient,
  command: AuthorizedCommand,
): Promise<CommandResult> {
  const id = matchingId(command);
  const branchId = optionalString(command.payload, "branchId");
  requireBranchScope(command, branchId);
  const key = requiredString(command.payload, "key").toLowerCase();
  const isEnabled = requiredBoolean(command.payload, "isEnabled");
  const configuration = asObject(command.payload.configuration ?? {}, "configuration");
  if (!/^[a-z][a-z0-9_.-]{1,63}$/.test(key)) {
    throw new RemoteCommandError("invalid-argument", "The feature flag key is invalid.");
  }
  const existing = await client.query<Record<string, unknown>>(
    `SELECT id, flag_key AS "key", is_enabled AS "isEnabled",
            configuration_json AS configuration, version,
            branch_id AS "branchId"
     FROM feature_flags WHERE id = $1 AND organization_id = $2 FOR UPDATE`,
    [id, command.organizationId],
  );
  const before = existing.rows[0] ?? null;
  const expectedVersion = optionalInteger(command.payload, "expectedVersion");
  if (before === null) {
    await client.query(
      `INSERT INTO feature_flags (
         id, organization_id, branch_id, branch_scope, flag_key, is_enabled,
         configuration_json, version, created_at, updated_at
       ) VALUES ($1, $2, $3, $4, $5, $6, $7::jsonb, 0, now(), now())`,
      [id, command.organizationId, branchId, branchId ?? "*", key, isEnabled,
        JSON.stringify(configuration)],
    );
  } else {
    if (expectedVersion !== null && before.version !== expectedVersion) {
      throw changedSetting();
    }
    const changed = await client.query(
      `UPDATE feature_flags SET is_enabled = $3, configuration_json = $4::jsonb,
         version = version + 1, updated_at = now()
       WHERE id = $1 AND organization_id = $2 AND version = $5`,
      [id, command.organizationId, isEnabled, JSON.stringify(configuration),
        before.version],
    );
    if (changed.rowCount !== 1) throw changedSetting();
  }
  const result = await client.query(
    `SELECT id, branch_id AS "branchId", flag_key AS key,
            is_enabled AS "isEnabled", configuration_json AS configuration,
            version, created_at AS "createdAt", updated_at AS "updatedAt"
     FROM feature_flags WHERE id = $1 AND organization_id = $2`,
    [id, command.organizationId],
  );
  return {featureFlag: result.rows[0], before};
}

async function settingResult(
  client: PoolClient,
  command: AuthorizedCommand,
  id: string,
  branchScoped: boolean,
): Promise<Record<string, unknown>> {
  const branchField = branchScoped ? "branch_id AS \"branchId\"," : "";
  const result = await client.query(
    `SELECT id, ${branchField} setting_key AS key, value_json AS value,
            version, updated_by_user_id AS "updatedByUserId",
            created_at AS "createdAt", updated_at AS "updatedAt"
     FROM ${branchScoped ? "branch_settings" : "organization_settings"}
     WHERE id = $1 AND organization_id = $2`,
    [id, command.organizationId],
  );
  return result.rows[0];
}

async function organizationSettingValue(
  client: PoolClient,
  organizationId: string,
  key: string,
): Promise<unknown | null> {
  const result = await client.query<{value: unknown}>(
    `SELECT value_json AS value FROM organization_settings
     WHERE organization_id = $1 AND setting_key = $2`,
    [organizationId, key],
  );
  return result.rows[0]?.value ?? null;
}

async function updateBranchProjection(
  client: PoolClient,
  command: AuthorizedCommand,
  key: string,
  value: unknown,
  branchScoped: boolean,
): Promise<void> {
  const column = legacyColumn(key);
  if (column === null) return;
  const params: unknown[] = [command.organizationId, value];
  let scope = "organization_id = $1";
  if (branchScoped) {
    params.push(command.branchId);
    scope += " AND id = $3";
  } else {
    params.push(key);
    scope += ` AND id NOT IN (
      SELECT branch_id FROM branch_settings
      WHERE organization_id = $1 AND setting_key = $3
    )`;
  }
  await client.query(
    `UPDATE branches SET ${column} = $2, updated_at = now() WHERE ${scope}`,
    params,
  );
}

function legacyColumn(key: string): string | null {
  return ({
    "inventory.allow_negative_stock": "allow_negative_stock",
    "inventory.adjustment_approval_threshold_milli":
      "adjustment_approval_threshold_milli",
    "sales.discount_approval_threshold_basis_points":
      "discount_approval_threshold_basis_points",
    "shifts.allow_multiple_open_per_user": "allow_multiple_open_shifts_per_user",
    "shifts.allow_sales_without_open_shift": "allow_sales_without_open_shift",
    "shifts.cash_discrepancy_approval_threshold_minor":
      "cash_discrepancy_approval_threshold_minor",
    "returns.approval_threshold_minor": "return_approval_threshold_minor",
    "returns.void_window_minutes": "void_window_minutes",
    "transfers.approval_threshold_milli": "transfer_approval_threshold_milli",
  } as Record<string, string>)[key] ?? null;
}

function validateSetting(key: string, value: unknown): void {
  const nullableThresholds = new Set([
    "inventory.adjustment_approval_threshold_milli",
    "sales.discount_approval_threshold_basis_points",
    "shifts.cash_discrepancy_approval_threshold_minor",
    "returns.approval_threshold_minor",
    "transfers.approval_threshold_milli",
  ]);
  if (value === null) {
    if (nullableThresholds.has(key)) return;
    throw new RemoteCommandError("invalid-argument", "The setting cannot be null.");
  }
  if (key === "tax.behavior" &&
      typeof value === "string" &&
      new Set(["per_product", "inclusive", "exclusive"]).has(value)) return;
  if (key === "receipt.header" &&
      typeof value === "string" && value.length >= 1 && value.length <= 80) return;
  if (key === "receipt.footer" && typeof value === "string" && value.length <= 160) return;
  if (key === "receipt.paper_width_characters" &&
      typeof value === "number" && new Set([32, 42, 48]).has(value)) return;
  if (new Set(["inventory.allow_negative_stock", "receipt.show_tax_breakdown",
    "shifts.allow_multiple_open_per_user", "shifts.allow_sales_without_open_shift",
    "sales.require_non_cash_reference"])
    .has(key) && typeof value === "boolean") return;
  if (new Set(["sales.discount_limit_basis_points",
    "sales.discount_approval_threshold_basis_points"]).has(key) &&
      Number.isSafeInteger(value) && (value as number) >= 0 &&
      (value as number) <= 10000) return;
  if (key === "returns.void_window_minutes" && Number.isSafeInteger(value) &&
      (value as number) >= 0 && (value as number) <= 10080) return;
  if (nullableThresholds.has(key) && Number.isSafeInteger(value) &&
      (value as number) >= 0) return;
  throw new RemoteCommandError("invalid-argument", "The setting value is invalid.");
}

function defaultSettingValue(key: string): unknown {
  return ({
    "inventory.allow_negative_stock": false,
    "inventory.adjustment_approval_threshold_milli": null,
    "sales.discount_approval_threshold_basis_points": null,
    "sales.require_non_cash_reference": false,
    "shifts.allow_multiple_open_per_user": false,
    "shifts.allow_sales_without_open_shift": false,
    "shifts.cash_discrepancy_approval_threshold_minor": null,
    "returns.approval_threshold_minor": null,
    "returns.void_window_minutes": 15,
    "transfers.approval_threshold_milli": null,
  } as Record<string, unknown>)[key];
}

function requireBranchScope(command: AuthorizedCommand, branchId: string | null): void {
  if (branchId !== null && branchId !== command.branchId) {
    throw new RemoteCommandError(
      "permission-denied",
      "The settings command is outside the authorized branch.",
    );
  }
}

function matchingId(command: AuthorizedCommand): string {
  const id = requiredString(command.payload, "id");
  if (id !== command.aggregateId) {
    throw new RemoteCommandError("invalid-argument", "Aggregate IDs do not match.");
  }
  return id;
}

function settingAuditValue(row: SettingRow): Record<string, unknown> {
  return {key: row.settingKey, value: row.value, version: row.version};
}

function changedSetting(): RemoteCommandError {
  return new RemoteCommandError(
    "failed-precondition",
    "The remote configuration changed. Refresh and try again.",
  );
}
