import {createHash} from "node:crypto";
import {PoolClient} from "pg";

import {RemoteCommandError} from "./remote_commands/command_types";

export const posBootstrapCollections = [
  "organization",
  "branch",
  "registers",
  "categories",
  "units",
  "taxCategories",
  "products",
  "productBarcodes",
  "productPrices",
  "stockLocations",
  "inventoryBalances",
  "organizationSettings",
  "branchSettings",
  "reasonCodes",
  "featureFlags",
] as const;

type BootstrapCollection = typeof posBootstrapCollections[number];

type BootstrapToken = {
  schemaVersion: 1;
  organizationId: string;
  branchId: string;
  createdAt: string;
  watermark: number;
};

type BootstrapQuery = {
  table: string;
  where: string;
  branchScoped: boolean;
};

const queryByCollection: Record<BootstrapCollection, BootstrapQuery> = {
  organization: {
    table: "organizations",
    where: "t.id = $1 AND t.is_active = true AND t.deleted_at IS NULL",
    branchScoped: false,
  },
  branch: {
    table: "branches",
    where: "t.organization_id = $1 AND t.id = $2 AND t.is_active = true AND t.deleted_at IS NULL",
    branchScoped: true,
  },
  registers: {
    table: "registers",
    where: "t.organization_id = $1 AND t.branch_id = $2 AND t.deleted_at IS NULL",
    branchScoped: true,
  },
  categories: {
    table: "categories",
    where: "t.organization_id = $1 AND t.deleted_at IS NULL",
    branchScoped: false,
  },
  units: {
    table: "units",
    where: "t.organization_id = $1 AND t.deleted_at IS NULL",
    branchScoped: false,
  },
  taxCategories: {
    table: "tax_categories",
    where: "t.organization_id = $1 AND t.deleted_at IS NULL",
    branchScoped: false,
  },
  products: {
    table: "products",
    where: "t.organization_id = $1 AND t.deleted_at IS NULL",
    branchScoped: false,
  },
  productBarcodes: {
    table: "product_barcodes",
    where: "t.organization_id = $1 AND t.deleted_at IS NULL",
    branchScoped: false,
  },
  productPrices: {
    table: "product_prices",
    where: "t.organization_id = $1 AND (t.branch_id IS NULL OR t.branch_id = $2)",
    branchScoped: true,
  },
  stockLocations: {
    table: "stock_locations",
    where: "t.organization_id = $1 AND t.branch_id = $2 AND t.is_default = true AND t.deleted_at IS NULL",
    branchScoped: true,
  },
  inventoryBalances: {
    table: "inventory_balances",
    where: `t.organization_id = $1 AND t.branch_id = $2 AND EXISTS (
      SELECT 1 FROM stock_locations sl
      WHERE sl.id = t.stock_location_id AND sl.organization_id = t.organization_id
        AND sl.branch_id = t.branch_id AND sl.is_default = true
        AND sl.is_active = true AND sl.deleted_at IS NULL
    )`,
    branchScoped: true,
  },
  organizationSettings: {
    table: "organization_settings",
    where: "t.organization_id = $1",
    branchScoped: false,
  },
  branchSettings: {
    table: "branch_settings",
    where: "t.organization_id = $1 AND t.branch_id = $2",
    branchScoped: true,
  },
  reasonCodes: {
    table: "reason_codes",
    where: "t.organization_id = $1 AND (t.branch_id IS NULL OR t.branch_id = $2) AND t.deleted_at IS NULL",
    branchScoped: true,
  },
  featureFlags: {
    table: "feature_flags",
    where: "t.organization_id = $1 AND (t.branch_id IS NULL OR t.branch_id = $2)",
    branchScoped: true,
  },
};

export async function getPosBootstrapPageForUser(
  client: PoolClient,
  input: {
    firebaseUid: string;
    organizationId: string;
    branchId: string;
    collection: string;
    cursor?: string | null;
    pageSize?: number | null;
    snapshotToken?: string | null;
  },
): Promise<Record<string, unknown>> {
  if (!posBootstrapCollections.includes(input.collection as BootstrapCollection)) {
    throw new RemoteCommandError("invalid-argument", "The bootstrap collection is invalid.");
  }
  const collection = input.collection as BootstrapCollection;
  await assertPosBootstrapAccess(client, input);

  const token = input.snapshotToken === undefined || input.snapshotToken === null ?
    await createBootstrapToken(client, input.organizationId, input.branchId) :
    parseBootstrapToken(input.snapshotToken, input.organizationId, input.branchId);
  const pageSize = Math.min(Math.max(input.pageSize ?? 250, 1), 500);
  const cursor = input.cursor ?? "";
  const query = queryByCollection[collection];
  const scopeValues = query.branchScoped ?
    [input.organizationId, input.branchId] :
    [input.organizationId];
  const cursorParameter = scopeValues.length + 1;
  const snapshotParameter = cursorParameter + 1;
  const limitParameter = snapshotParameter + 1;
  const result = await client.query<{id: string; row_json: Record<string, unknown>}>(
    `SELECT t.id, to_jsonb(t) AS row_json
     FROM ${query.table} t
     WHERE ${query.where}
       AND ($${cursorParameter}::text IS NULL OR t.id > $${cursorParameter}::text)
       AND t.updated_at <= $${snapshotParameter}::timestamptz
     ORDER BY t.id
     LIMIT $${limitParameter}::integer`,
    [...scopeValues, cursor === "" ? null : cursor, token.createdAt, pageSize + 1],
  );
  const hasMore = result.rows.length > pageSize;
  const page = result.rows.slice(0, pageSize);
  const rows = page.map((row) => row.row_json);
  const nextCursor = hasMore ? page[page.length - 1].id : null;
  const checksum = createHash("sha256")
    .update(JSON.stringify({collection, cursor, rows}))
    .digest("hex");

  return {
    snapshotToken: encodeToken(token),
    collection,
    cursor,
    nextCursor,
    pageSize,
    watermark: token.watermark,
    checksum,
    rows,
    complete: !hasMore,
  };
}

async function assertPosBootstrapAccess(
  client: PoolClient,
  input: {firebaseUid: string; organizationId: string; branchId: string},
): Promise<void> {
  const access = await client.query(
    `SELECT 1
     FROM app_users au
     INNER JOIN user_role_assignments ura
       ON ura.user_id = au.id AND ura.organization_id = au.organization_id
       AND (ura.branch_id IS NULL OR ura.branch_id = $3) AND ura.revoked_at IS NULL
     INNER JOIN roles r
       ON r.id = ura.role_id AND r.organization_id = ura.organization_id
       AND r.is_active = true AND r.deleted_at IS NULL
     INNER JOIN role_permissions rp ON rp.role_id = r.id
     INNER JOIN branches b
       ON b.id = $3 AND b.organization_id = au.organization_id
       AND b.is_active = true AND b.deleted_at IS NULL
     WHERE au.firebase_uid = $1 AND au.organization_id = $2
       AND au.status = 'active' AND au.deleted_at IS NULL
       AND rp.permission_code IN ('sales.process', 'registers.manage')
     LIMIT 1`,
    [input.firebaseUid, input.organizationId, input.branchId],
  );
  if (access.rowCount !== 1) {
    throw new RemoteCommandError(
      "permission-denied",
      "Point-of-sale bootstrap access is not available for this branch.",
    );
  }
}

async function createBootstrapToken(
  client: PoolClient,
  organizationId: string,
  branchId: string,
): Promise<BootstrapToken> {
  const watermark = await client.query<{watermark: string}>(
    `SELECT COALESCE(max(sequence), 0)::text AS watermark
     FROM change_feed
     WHERE organization_id = $1 AND (branch_id IS NULL OR branch_id = $2)`,
    [organizationId, branchId],
  );
  return {
    schemaVersion: 1,
    organizationId,
    branchId,
    createdAt: new Date().toISOString(),
    watermark: Number(watermark.rows[0]?.watermark ?? 0),
  };
}

function parseBootstrapToken(
  encoded: string,
  organizationId: string,
  branchId: string,
): BootstrapToken {
  try {
    const parsed = JSON.parse(
      Buffer.from(encoded, "base64url").toString("utf8"),
    ) as Partial<BootstrapToken>;
    if (parsed.schemaVersion !== 1 || parsed.organizationId !== organizationId ||
        parsed.branchId !== branchId || typeof parsed.createdAt !== "string" ||
        typeof parsed.watermark !== "number" ||
        Number.isNaN(new Date(parsed.createdAt).valueOf())) {
      throw new Error("scope mismatch");
    }
    return parsed as BootstrapToken;
  } catch (_) {
    throw new RemoteCommandError(
      "invalid-argument",
      "The bootstrap snapshot token is invalid for this scope.",
    );
  }
}

function encodeToken(token: BootstrapToken): string {
  return Buffer.from(JSON.stringify(token), "utf8").toString("base64url");
}
