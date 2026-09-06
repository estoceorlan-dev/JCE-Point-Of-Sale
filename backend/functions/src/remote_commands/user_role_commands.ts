import {PoolClient} from "pg";
import {requireSafeAccessState} from "./access_state_guard";

import {
  asObject,
  AuthorizedCommand,
  CommandResult,
  RemoteCommandError,
  requiredArray,
  requiredInteger,
  requiredString,
  optionalString,
} from "./command_types";

const protectedPermissions = [
  "users.manage",
  "roles.manage",
  "branches.manage",
];

export async function applyUserRoleCommand(
  client: PoolClient,
  command: AuthorizedCommand,
): Promise<CommandResult> {
  // Serialize organization access changes so concurrent removals cannot each
  // observe the other administrator and jointly remove the last one.
  await client.query("SELECT pg_advisory_xact_lock(hashtextextended($1, 0))",
    [`access-administration:${command.organizationId}`]);
  if (command.commandType.startsWith("user.")) {
    const result = await applyUserCommand(client, command);
    if (["user.assignments.replace", "user.status.set"].includes(command.commandType)) {
      await requireSafeAccessState(client, command);
    }
    return result;
  }
  if (command.commandType.startsWith("role.")) {
    const result = await applyRoleCommand(client, command);
    if (command.commandType !== "role.create") await requireSafeAccessState(client, command);
    return result;
  }
  throw new RemoteCommandError(
    "invalid-argument",
    `Unsupported access command: ${command.commandType}.`,
  );
}

async function applyUserCommand(
  client: PoolClient,
  command: AuthorizedCommand,
): Promise<CommandResult> {
  if (command.commandType === "user.invite") {
    const id = requiredString(command.payload, "id");
    if (id !== command.aggregateId) {
      throw new RemoteCommandError("invalid-argument", "User IDs do not match.");
    }
    const email = validEmail(command.payload);
    const displayName = validDisplayName(command.payload);
    const assignments = await validAssignments(client, command);
    if (assignments.length === 0) {
      throw new RemoteCommandError("invalid-argument", "At least one role is required.");
    }
    const inserted = await client.query(
      `INSERT INTO app_users (
         id, organization_id, email, display_name, status, invited_at,
         version, created_at, updated_at
       ) VALUES ($1, $2, $3, $4, 'invited', now(), 0, now(), now())
       RETURNING ${userProjection}`,
      [id, command.organizationId, email, displayName],
    );
    await insertAssignments(client, command, id, assignments);
    return {
      user: inserted.rows[0],
      assignments: await assignmentsFor(client, command.organizationId, id),
    };
  }

  await requireUser(client, command);
  if (command.commandType === "user.update") {
    const expectedVersion = requiredInteger(command.payload, "expectedVersion");
    const email = validEmail(command.payload);
    const displayName = validDisplayName(command.payload);
    const result = await client.query(
      `UPDATE app_users SET email = $4, display_name = $5,
         version = version + 1, updated_at = now()
       WHERE id = $1 AND organization_id = $2 AND version = $3
         AND deleted_at IS NULL
       RETURNING ${userProjection}`,
      [command.aggregateId, command.organizationId, expectedVersion, email, displayName],
    );
    requireChanged(result.rowCount, "staff account");
    return {user: result.rows[0]};
  }

  if (command.commandType === "user.assignments.replace") {
    const assignments = await validAssignments(client, command);
    await requireAdministratorRemains(
      client,
      command.organizationId,
      command.aggregateId,
      assignments,
    );
    await client.query(
      `UPDATE user_role_assignments SET revoked_at = now(),
         version = version + 1, updated_at = now()
       WHERE organization_id = $1 AND user_id = $2 AND revoked_at IS NULL`,
      [command.organizationId, command.aggregateId],
    );
    await insertAssignments(client, command, command.aggregateId, assignments);
    const user = await client.query(
      `UPDATE app_users SET version = version + 1, updated_at = now()
       WHERE id = $1 AND organization_id = $2 AND version = $3
       RETURNING ${userProjection}`,
      [command.aggregateId, command.organizationId, requiredInteger(command.payload, "expectedVersion")],
    );
    requireChanged(user.rowCount, "staff account");
    return {
      user: user.rows[0],
      assignments: await assignmentsFor(
        client,
        command.organizationId,
        command.aggregateId,
      ),
    };
  }

  if (command.commandType === "user.status.set") {
    const status = requiredString(command.payload, "status").toLowerCase();
    const expectedVersion = requiredInteger(command.payload, "expectedVersion");
    if (!["invited", "active", "suspended", "disabled"].includes(status)) {
      throw new RemoteCommandError("invalid-argument", "The account status is invalid.");
    }
    if (status !== "active") {
      await requireAdministratorRemains(
        client,
        command.organizationId,
        command.aggregateId,
        [],
      );
    }
    const result = await client.query(
      `UPDATE app_users SET status = $4,
         activated_at = CASE WHEN $4 = 'active' THEN COALESCE(activated_at, now())
                             ELSE activated_at END,
         version = version + 1, updated_at = now()
       WHERE id = $1 AND organization_id = $2 AND version = $3
         AND deleted_at IS NULL
       RETURNING ${userProjection}`,
      [command.aggregateId, command.organizationId, expectedVersion, status],
    );
    requireChanged(result.rowCount, "staff account");
    if (status === "suspended" || status === "disabled") {
      await client.query(
        `UPDATE user_role_assignments SET revoked_at = now(),
           version = version + 1, updated_at = now()
         WHERE organization_id = $1 AND user_id = $2 AND revoked_at IS NULL`,
        [command.organizationId, command.aggregateId],
      );
    }
    return {user: result.rows[0], assignments: []};
  }

  throw new RemoteCommandError(
    "invalid-argument",
    `Unsupported user command: ${command.commandType}.`,
  );
}

async function applyRoleCommand(
  client: PoolClient,
  command: AuthorizedCommand,
): Promise<CommandResult> {
  if (command.commandType === "role.create") {
    const id = requiredString(command.payload, "id");
    if (id !== command.aggregateId) {
      throw new RemoteCommandError("invalid-argument", "Role IDs do not match.");
    }
    const draft = await validRole(client, command);
    const result = await client.query(
      `INSERT INTO roles (
         id, organization_id, code, name, description, is_active,
         version, created_at, updated_at
       ) VALUES ($1, $2, $3, $4, $5, true, 0, now(), now())
       RETURNING ${roleProjection}`,
      [id, command.organizationId, draft.code, draft.name, draft.description],
    );
    await replaceRolePermissions(client, id, draft.permissions);
    return {role: {...result.rows[0], permissions: draft.permissions}};
  }

  const role = await requireRole(client, command);
  if (command.commandType === "role.update") {
    const expectedVersion = requiredInteger(command.payload, "expectedVersion");
    const draft = await validRole(client, command);
    const result = await client.query(
      `UPDATE roles SET code = $4, name = $5, description = $6,
         version = version + 1, updated_at = now()
       WHERE id = $1 AND organization_id = $2 AND version = $3
         AND deleted_at IS NULL
       RETURNING ${roleProjection}`,
      [
        command.aggregateId,
        command.organizationId,
        expectedVersion,
        draft.code,
        draft.name,
        draft.description,
      ],
    );
    requireChanged(result.rowCount, "role");
    await replaceRolePermissions(client, command.aggregateId, draft.permissions);
    return {role: {...result.rows[0], permissions: draft.permissions}};
  }

  if (command.commandType === "role.archive" ||
      command.commandType === "role.restore") {
    const archived = command.commandType === "role.archive";
    const expectedVersion = requiredInteger(command.payload, "expectedVersion");
    if (archived) {
      const assigned = await client.query(
        `SELECT 1 FROM user_role_assignments
         WHERE organization_id = $1 AND role_id = $2 AND revoked_at IS NULL
         LIMIT 1`,
        [command.organizationId, command.aggregateId],
      );
      if (assigned.rowCount !== 0) {
        throw new RemoteCommandError(
          "failed-precondition",
          "Reassign staff before archiving this role.",
        );
      }
    }
    const result = await client.query(
      `UPDATE roles SET is_active = $4,
         deleted_at = CASE WHEN $4 THEN NULL ELSE now() END,
         version = version + 1, updated_at = now()
       WHERE id = $1 AND organization_id = $2 AND version = $3
       RETURNING ${roleProjection}`,
      [command.aggregateId, command.organizationId, expectedVersion, !archived],
    );
    requireChanged(result.rowCount, "role");
    return {
      role: {
        ...result.rows[0],
        permissions: await permissionCodesFor(client, command.aggregateId),
      },
    };
  }

  throw new RemoteCommandError(
    "invalid-argument",
    `Unsupported role command: ${command.commandType}.`,
  );
}

type AssignmentInput = {id: string; roleId: string; branchId: string | null};

async function validAssignments(
  client: PoolClient,
  command: AuthorizedCommand,
): Promise<AssignmentInput[]> {
  const values = requiredArray(command.payload, "assignments");
  const unique = new Set<string>();
  const assignments: AssignmentInput[] = [];
  for (const value of values) {
    const item = asObject(value, "assignment");
    const assignment = {
      id: requiredString(item, "id"),
      roleId: requiredString(item, "roleId"),
      branchId: optionalString(item, "branchId"),
    };
    const key = `${assignment.roleId}|${assignment.branchId ?? "*"}`;
    if (!unique.add(key)) continue;
    const valid = await client.query(
      `SELECT r.id FROM roles r
       LEFT JOIN branches b ON b.id = $3 AND b.organization_id = r.organization_id
         AND b.is_active = true AND b.deleted_at IS NULL
       WHERE r.id = $1 AND r.organization_id = $2
         AND r.is_active = true AND r.deleted_at IS NULL
         AND ($3::text IS NULL OR b.id IS NOT NULL)`,
      [assignment.roleId, command.organizationId, assignment.branchId],
    );
    if (valid.rowCount !== 1) {
      throw new RemoteCommandError(
        "invalid-argument",
        "An assigned role or branch is unavailable.",
      );
    }
    assignments.push(assignment);
  }
  return assignments;
}

async function insertAssignments(
  client: PoolClient,
  command: AuthorizedCommand,
  userId: string,
  assignments: AssignmentInput[],
): Promise<void> {
  for (const assignment of assignments) {
    await client.query(
      `INSERT INTO user_role_assignments (
         id, organization_id, branch_id, user_id, role_id,
         version, assigned_at, updated_at
       ) VALUES ($1, $2, $3, $4, $5, 0, now(), now())`,
      [
        assignment.id,
        command.organizationId,
        assignment.branchId,
        userId,
        assignment.roleId,
      ],
    );
  }
}

async function validRole(client: PoolClient, command: AuthorizedCommand) {
  const code = requiredString(command.payload, "code").toLowerCase();
  const name = requiredString(command.payload, "name");
  const description = optionalString(command.payload, "description");
  if (!/^[a-z][a-z0-9_]{1,39}$/.test(code) || name.length < 2 || name.length > 80) {
    throw new RemoteCommandError("invalid-argument", "The role profile is invalid.");
  }
  const permissions = [...new Set(requiredArray(command.payload, "permissions").map(
    (value) => {
      if (typeof value !== "string") {
        throw new RemoteCommandError("invalid-argument", "Permission codes must be strings.");
      }
      return value;
    },
  ))];
  if (permissions.length === 0) {
    throw new RemoteCommandError("invalid-argument", "At least one permission is required.");
  }
  const existing = await client.query(
    "SELECT code FROM permissions WHERE code = ANY($1::text[])",
    [permissions],
  );
  if (existing.rowCount !== permissions.length) {
    throw new RemoteCommandError("invalid-argument", "A permission code is unavailable.");
  }
  return {code, name, description, permissions};
}

async function replaceRolePermissions(
  client: PoolClient,
  roleId: string,
  permissions: string[],
): Promise<void> {
  await client.query("DELETE FROM role_permissions WHERE role_id = $1", [roleId]);
  for (const permission of permissions) {
    await client.query(
      `INSERT INTO role_permissions (role_id, permission_code, granted_at)
       VALUES ($1, $2, now())`,
      [roleId, permission],
    );
  }
}

async function requireAdministratorRemains(
  client: PoolClient,
  organizationId: string,
  targetUserId: string,
  replacement: AssignmentInput[],
): Promise<void> {
  const organizationRoleIds = replacement
    .filter((value) => value.branchId === null)
    .map((value) => value.roleId);
  if (organizationRoleIds.length > 0) {
    const grants = await client.query<{permission_code: string}>(
      `SELECT DISTINCT permission_code FROM role_permissions
       WHERE role_id = ANY($1::text[])`,
      [organizationRoleIds],
    );
    const codes = new Set(grants.rows.map((row) => row.permission_code));
    if (protectedPermissions.every((value) => codes.has(value))) return;
  }
  const others = await fullAdministratorRows(client, organizationId, targetUserId);
  if (others.rowCount === 0) {
    throw new RemoteCommandError(
      "failed-precondition",
      "This change would remove the last full organization administrator.",
    );
  }
}

async function requireRoleChangeKeepsAdministrator(
  client: PoolClient,
  organizationId: string,
  roleId: string,
): Promise<void> {
  const impacted = await client.query<{user_id: string}>(
    `SELECT DISTINCT user_id FROM user_role_assignments
     WHERE organization_id = $1 AND role_id = $2 AND branch_id IS NULL
       AND revoked_at IS NULL`,
    [organizationId, roleId],
  );
  for (const row of impacted.rows) {
    const others = await fullAdministratorRows(
      client,
      organizationId,
      null,
      roleId,
    );
    if (others.rowCount === 0) {
      throw new RemoteCommandError(
        "failed-precondition",
        "This role change would remove the last full organization administrator.",
      );
    }
  }
}

function fullAdministratorRows(
  client: PoolClient,
  organizationId: string,
  excludedUserId: string | null,
  excludedRoleId?: string,
) {
  return client.query(
    `SELECT ura.user_id
     FROM user_role_assignments ura
     JOIN app_users au ON au.id = ura.user_id AND au.status = 'active'
       AND au.deleted_at IS NULL
     JOIN roles r ON r.id = ura.role_id AND r.is_active = true
       AND r.deleted_at IS NULL
     JOIN role_permissions rp ON rp.role_id = r.id
     WHERE ura.organization_id = $1 AND ura.branch_id IS NULL
       AND ura.revoked_at IS NULL AND ($2::text IS NULL OR ura.user_id <> $2)
       AND ($3::text IS NULL OR ura.role_id <> $3)
       AND rp.permission_code = ANY($4::text[])
     GROUP BY ura.user_id
     HAVING count(DISTINCT rp.permission_code) = 3`,
    [organizationId, excludedUserId, excludedRoleId ?? null, protectedPermissions],
  );
}

async function requireUser(client: PoolClient, command: AuthorizedCommand) {
  const result = await client.query(
    `SELECT id FROM app_users WHERE id = $1 AND organization_id = $2
       AND deleted_at IS NULL`,
    [command.aggregateId, command.organizationId],
  );
  if (result.rowCount !== 1) {
    throw new RemoteCommandError("not-found", "The staff account does not exist.");
  }
}

async function requireRole(client: PoolClient, command: AuthorizedCommand) {
  const result = await client.query(
    "SELECT id FROM roles WHERE id = $1 AND organization_id = $2",
    [command.aggregateId, command.organizationId],
  );
  if (result.rowCount !== 1) {
    throw new RemoteCommandError("not-found", "The role does not exist.");
  }
  return result.rows[0];
}

function validEmail(payload: Record<string, unknown>): string {
  const email = requiredString(payload, "email").toLowerCase();
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    throw new RemoteCommandError("invalid-argument", "The email address is invalid.");
  }
  return email;
}

function validDisplayName(payload: Record<string, unknown>): string {
  const name = requiredString(payload, "displayName");
  if (name.length < 2 || name.length > 80) {
    throw new RemoteCommandError("invalid-argument", "The display name is invalid.");
  }
  return name;
}

function requireChanged(rowCount: number | null, entity: string): void {
  if (rowCount !== 1) {
    throw new RemoteCommandError("aborted", `The ${entity} changed. Refresh and retry.`);
  }
}

async function assignmentsFor(
  client: PoolClient,
  organizationId: string,
  userId: string,
) {
  const result = await client.query(
    `SELECT ura.id, ura.user_id AS "userId", ura.role_id AS "roleId",
       ura.branch_id AS "branchId", r.name AS "roleName", b.name AS "branchName",
       ura.version, ura.assigned_at AS "assignedAt",
       ura.updated_at AS "updatedAt", ura.revoked_at AS "revokedAt"
     FROM user_role_assignments ura
     JOIN roles r ON r.id = ura.role_id
     LEFT JOIN branches b ON b.id = ura.branch_id
     WHERE ura.organization_id = $1 AND ura.user_id = $2
       AND ura.revoked_at IS NULL`,
    [organizationId, userId],
  );
  return result.rows;
}

async function permissionCodesFor(client: PoolClient, roleId: string) {
  const result = await client.query<{permission_code: string}>(
    "SELECT permission_code FROM role_permissions WHERE role_id = $1 ORDER BY permission_code",
    [roleId],
  );
  return result.rows.map((row) => row.permission_code);
}

const userProjection = `id, organization_id AS "organizationId", firebase_uid AS "firebaseUid",
  email, display_name AS "displayName", status, invited_at AS "invitedAt",
  activated_at AS "activatedAt", version, created_at AS "createdAt",
  updated_at AS "updatedAt", deleted_at AS "deletedAt"`;

const roleProjection = `id, organization_id AS "organizationId", code, name, description,
  is_active AS "isActive", version, created_at AS "createdAt",
  updated_at AS "updatedAt", deleted_at AS "deletedAt"`;
