import {createHash} from "node:crypto";
import {PoolClient} from "pg";

import {RemoteCommandError} from "./remote_commands/command_types";

type ChangeRow = {
  sequence: string;
  organization_id: string;
  branch_id: string | null;
  aggregate_type: string;
  aggregate_id: string;
  operation_id: string;
  change_type: string;
  version: number;
  payload_json: Record<string, unknown>;
  occurred_at: Date;
};

export async function pullAuthorizedChangesForUser(
  client: PoolClient,
  input: {
    firebaseUid: string;
    organizationId: string;
    branchId: string;
    afterSequence: number;
    limit: number;
    projection: string;
  },
): Promise<Record<string, unknown>> {
  if (!Number.isSafeInteger(input.afterSequence) || input.afterSequence < 0 ||
      !Number.isSafeInteger(input.limit) || input.limit < 1 || input.limit > 500 ||
      !["pos", "administration"].includes(input.projection)) {
    throw new RemoteCommandError("invalid-argument", "The change pull request is invalid.");
  }
  const access = await client.query<{permission_codes: string[]}>(
    `SELECT COALESCE(array_agg(DISTINCT rp.permission_code), ARRAY[]::text[])
       AS permission_codes
     FROM app_users au
     INNER JOIN user_role_assignments ura
       ON ura.user_id = au.id AND ura.organization_id = au.organization_id
       AND (ura.branch_id IS NULL OR ura.branch_id = $3) AND ura.revoked_at IS NULL
     INNER JOIN roles r
       ON r.id = ura.role_id AND r.organization_id = ura.organization_id
       AND r.is_active = true AND r.deleted_at IS NULL
     LEFT JOIN role_permissions rp ON rp.role_id = r.id
     INNER JOIN branches b
       ON b.id = $3 AND b.organization_id = au.organization_id
       AND b.is_active = true AND b.deleted_at IS NULL
     WHERE au.firebase_uid = $1 AND au.organization_id = $2
       AND au.status = 'active' AND au.deleted_at IS NULL
     GROUP BY au.id`,
    [input.firebaseUid, input.organizationId, input.branchId],
  );
  if (access.rowCount !== 1) {
    throw new RemoteCommandError("permission-denied", "Active branch access is required.");
  }
  const permissions = new Set(access.rows[0].permission_codes);
  if (input.projection === "pos" && !permissions.has("sales.process") &&
      !permissions.has("registers.manage")) {
    throw new RemoteCommandError("permission-denied", "POS access is required.");
  }

  const readableTypes = allAggregateTypes.filter((type) =>
    canRead(type, permissions, input.projection));
  const rows = await client.query<ChangeRow>(
    `SELECT sequence::text, organization_id, branch_id, aggregate_type,
       aggregate_id, operation_id, change_type, version, payload_json,
       occurred_at
     FROM change_feed
     WHERE organization_id = $1 AND sequence > $2
       AND (branch_id IS NULL OR branch_id = $3)
     ORDER BY sequence
     LIMIT $4`,
    [
      input.organizationId,
      input.afterSequence,
      input.branchId,
      input.limit,
    ],
  );
  const readable = new Set(readableTypes);
  const authorized = rows.rows.filter((row) => readable.has(row.aggregate_type));
  const scannedThrough = rows.rows[rows.rows.length - 1]?.sequence;
  return {
    schemaVersion: 2,
    organizationId: input.organizationId,
    branchId: input.branchId,
    projection: input.projection,
    permissionDigest: createHash("sha256")
      .update([...permissions].sort().join("\n"))
      .digest("hex"),
    nextCursor: Number(scannedThrough ?? input.afterSequence),
    hasMore: rows.rows.length === input.limit,
    changes: authorized.map((row) => ({
      sequence: Number(row.sequence),
      organizationId: row.organization_id,
      branchId: row.branch_id,
      aggregateType: row.aggregate_type,
      aggregateId: row.aggregate_id,
      operationId: row.operation_id,
      changeType: row.change_type,
      version: row.version,
      payload: row.payload_json,
      occurredAt: row.occurred_at.toISOString(),
    })),
  };
}

const allAggregateTypes = [
  "organization_setting",
  "branch_setting",
  "reason_code",
  "feature_flag",
  "branch",
  "app_user",
  "role",
  "user_role_assignment",
  "register",
  "register_claim",
  "category",
  "unit",
  "tax_category",
  "product",
  "product_price",
  "product_image",
  "stock_location",
  "inventory_balance",
  "inventory_transaction",
  "shift",
  "sale",
  "sale_correction",
  "receipt_reprint_event",
  "customer",
  "loyalty_account",
];

function canRead(
  aggregateType: string,
  permissions: Set<string>,
  projection: string,
): boolean {
  if (projection === "pos") {
    return [
      "organization_setting",
      "branch_setting",
      "reason_code",
      "feature_flag",
      "branch",
      "register",
      "register_claim",
      "category",
      "unit",
      "tax_category",
      "product",
      "product_price",
      "product_image",
      "stock_location",
      "inventory_balance",
      "inventory_transaction",
      "shift",
      "sale",
      "sale_correction",
      "receipt_reprint_event",
      "customer",
      "loyalty_account",
    ].includes(aggregateType);
  }
  const requirements: Record<string, string> = {
    branch: "branches.manage",
    app_user: "users.manage",
    role: "roles.manage",
    user_role_assignment: "users.manage",
    register: "registers.manage",
    register_claim: "registers.manage",
    product: "products.manage",
    category: "products.manage",
    unit: "products.manage",
    tax_category: "products.manage",
    stock_location: "inventory.manage",
    inventory_balance: "inventory.manage",
    inventory_transaction: "inventory.manage",
    sale: "reports.view",
    shift: "reports.view",
    customer: "customers.view",
    loyalty_account: "loyalty.manage",
    organization_setting: "settings.manage",
    branch_setting: "settings.manage",
    reason_code: "settings.manage",
    feature_flag: "settings.manage",
  };
  const required = requirements[aggregateType];
  return required !== undefined && permissions.has(required);
}
