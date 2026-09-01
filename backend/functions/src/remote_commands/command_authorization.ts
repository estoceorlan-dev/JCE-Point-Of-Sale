import {PoolClient} from "pg";

import {
  AuthorizedCommand,
  RemoteCommandError,
  RemoteCommandInput,
} from "./command_types";

type AccessRow = {
  actor_user_id: string;
  permission_codes: string[];
};

const permissionByCommandPrefix: ReadonlyArray<[string, string]> = [
  ["product", "products.manage"],
  ["category", "products.manage"],
  ["unit", "products.manage"],
  ["inventory", "inventory.manage"],
  ["stock_location", "inventory.manage"],
  ["stock_count", "inventory.manage"],
  ["register", "registers.manage"],
  ["shift", "sales.process"],
  ["sale", "sales.process"],
  ["transfer", "inventory.manage"],
  ["supplier", "suppliers.manage"],
  ["purchase_order", "purchases.create"],
];

const permissionByCommand: Readonly<Record<string, string>> = {
  "branch.update_name": "settings.manage",
  "branch.shift_policy.update": "registers.manage",
  "branch.discount_policy.update": "settings.manage",
  "branch.correction_policy.update": "settings.manage",
  "branch.transfer_policy.configure": "settings.manage",
  "transfer.approve": "transfers.approve",
  "transfer.reject": "transfers.approve",
  "transfer.correct_receipt": "transfers.approve",
  "purchase_order.approve": "purchases.approve",
  "purchase_order.receive": "purchases.receive",
  "sale.return": "sales.returns.process",
  "sale.void": "sales.returns.process",
};

export async function authorizeCommand(
  client: PoolClient,
  input: RemoteCommandInput,
): Promise<AuthorizedCommand> {
  const permission = requiredPermission(input.commandType);
  const result = await client.query<AccessRow>(
    `
      SELECT
        au.id AS actor_user_id,
        COALESCE(
          array_agg(DISTINCT rp.permission_code)
            FILTER (WHERE rp.permission_code IS NOT NULL),
          ARRAY[]::text[]
        ) AS permission_codes
      FROM app_users au
      INNER JOIN organizations o
        ON o.id = au.organization_id
       AND o.is_active = true
       AND o.deleted_at IS NULL
      INNER JOIN branches b
        ON b.id = $3
       AND b.organization_id = au.organization_id
       AND b.is_active = true
       AND b.deleted_at IS NULL
      INNER JOIN user_role_assignments ura
        ON ura.user_id = au.id
       AND ura.organization_id = au.organization_id
       AND (ura.branch_id IS NULL OR ura.branch_id = b.id)
       AND ura.revoked_at IS NULL
      INNER JOIN roles r
        ON r.id = ura.role_id
       AND r.organization_id = ura.organization_id
       AND r.is_active = true
       AND r.deleted_at IS NULL
      LEFT JOIN role_permissions rp ON rp.role_id = r.id
      WHERE au.firebase_uid = $1
        AND au.organization_id = $2
        AND au.status = 'active'
        AND au.deleted_at IS NULL
      GROUP BY au.id
    `,
    [input.firebaseUid, input.organizationId, input.branchId],
  );
  if (result.rowCount !== 1) {
    throw new RemoteCommandError(
      "permission-denied",
      "The authenticated user is not assigned to this organization and branch.",
    );
  }
  const permissions = new Set(result.rows[0].permission_codes);
  if (!permissions.has(permission)) {
    throw new RemoteCommandError(
      "permission-denied",
      `The ${permission} permission is required.`,
    );
  }
  return {
    ...input,
    actorUserId: result.rows[0].actor_user_id,
    permissions,
  };
}

function requiredPermission(commandType: string): string {
  const exactPermission = permissionByCommand[commandType];
  if (exactPermission !== undefined) return exactPermission;
  const mapping = permissionByCommandPrefix.find(
    ([prefix]) => commandType === prefix || commandType.startsWith(`${prefix}.`),
  );
  if (mapping === undefined) {
    throw new RemoteCommandError(
      "invalid-argument",
      `Unsupported command type: ${commandType}.`,
    );
  }
  return mapping[1];
}
