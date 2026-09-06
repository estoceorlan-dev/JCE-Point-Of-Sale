import {PoolClient} from "pg";
import {AuthorizedCommand, RemoteCommandError} from "./command_types";

const protectedPermissions = ["users.manage", "roles.manage", "branches.manage"];

/** Called after the mutation, before commit, while holding the organization
 * access lock. Checks the resulting permission union, including split roles. */
export async function requireSafeAccessState(client: PoolClient, command: AuthorizedCommand): Promise<void> {
  const access = await client.query<{user_id: string; permission_codes: string[]}>(`
    SELECT ura.user_id, array_agg(DISTINCT rp.permission_code) AS permission_codes
    FROM user_role_assignments ura
    JOIN app_users au ON au.id = ura.user_id AND au.organization_id = ura.organization_id
      AND au.status = 'active' AND au.deleted_at IS NULL
    JOIN roles r ON r.id = ura.role_id AND r.organization_id = ura.organization_id
      AND r.is_active = true AND r.deleted_at IS NULL
    JOIN role_permissions rp ON rp.role_id = r.id
    WHERE ura.organization_id = $1 AND ura.branch_id IS NULL AND ura.revoked_at IS NULL
      AND rp.permission_code = ANY($2::text[])
    GROUP BY ura.user_id
  `, [command.organizationId, protectedPermissions]);
  const own = new Set(access.rows.find((row) => row.user_id === command.actorUserId)?.permission_codes ?? []);
  if (protectedPermissions.some((code) => command.permissions.has(code) && !own.has(code))) {
    throw new RemoteCommandError("failed-precondition", "This change would remove your own administration access.");
  }
  if (!access.rows.some((row) => protectedPermissions.every((code) => row.permission_codes.includes(code)))) {
    throw new RemoteCommandError("failed-precondition", "Keep at least one active full organization administrator.");
  }
}
