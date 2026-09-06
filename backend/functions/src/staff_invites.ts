import {PoolClient} from "pg";
import {randomUUID} from "node:crypto";

export class StaffInviteError extends Error {
  constructor(
    readonly reason: "permission-denied" | "not-found" | "failed-precondition",
    message: string,
  ) {
    super(message);
  }
}

export async function bindStaffIdentity(
  client: PoolClient,
  input: {
    actorFirebaseUid: string;
    organizationId: string;
    userId: string;
    targetFirebaseUid: string;
  },
): Promise<{email: string; displayName: string}> {
  await requireOrganizationPermission(
    client,
    input.actorFirebaseUid,
    input.organizationId,
    "users.manage",
  );
  await client.query("BEGIN");
  try {
  const result = await client.query(
    `UPDATE app_users SET firebase_uid = $3, updated_at = now(),
       version = version + 1
     WHERE id = $1 AND organization_id = $2 AND status = 'invited'
       AND deleted_at IS NULL AND (firebase_uid IS NULL OR firebase_uid = $3)
     RETURNING *`,
    [input.userId, input.organizationId, input.targetFirebaseUid],
  );
  if (result.rowCount !== 1) {
    throw new StaffInviteError(
      "failed-precondition",
      "The invitation is unavailable or is already bound to another identity.",
    );
  }
  const actor = await client.query(
    "SELECT id FROM app_users WHERE organization_id = $1 AND firebase_uid = $2",
    [input.organizationId, input.actorFirebaseUid],
  );
  await publishStaffLifecycle(client, result.rows[0], "user.invite.bound",
    input.actorFirebaseUid, actor.rows[0].id);
  await client.query("COMMIT");
  return {email: result.rows[0].email, displayName: result.rows[0].display_name};
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  }
}

export async function loadInvitedStaff(
  client: PoolClient,
  input: {
    actorFirebaseUid: string;
    organizationId: string;
    userId: string;
  },
): Promise<{email: string; displayName: string; firebaseUid: string | null}> {
  await requireOrganizationPermission(
    client,
    input.actorFirebaseUid,
    input.organizationId,
    "users.manage",
  );
  const result = await client.query<{
    email: string;
    display_name: string;
    firebase_uid: string | null;
  }>(
    `SELECT email, display_name, firebase_uid FROM app_users
     WHERE id = $1 AND organization_id = $2 AND status = 'invited'
       AND deleted_at IS NULL`,
    [input.userId, input.organizationId],
  );
  if (result.rowCount !== 1) {
    throw new StaffInviteError("not-found", "The staff invitation was not found.");
  }
  return {
    email: result.rows[0].email,
    displayName: result.rows[0].display_name,
    firebaseUid: result.rows[0].firebase_uid,
  };
}

export async function acceptStaffInvite(
  client: PoolClient,
  input: {
    firebaseUid: string;
    email: string;
    organizationId?: string;
  },
): Promise<number> {
  await client.query("BEGIN");
  try {
  const result = await client.query(
    `UPDATE app_users SET status = 'active', activated_at = now(),
       version = version + 1, updated_at = now()
     WHERE ($1::text IS NULL OR organization_id = $1) AND firebase_uid = $2
       AND lower(email) = lower($3) AND status = 'invited'
       AND deleted_at IS NULL
       AND EXISTS (SELECT 1 FROM organizations o WHERE o.id = app_users.organization_id
         AND o.is_active = true AND o.deleted_at IS NULL)
     RETURNING *`,
    [input.organizationId ?? null, input.firebaseUid, input.email],
  );
  if (input.organizationId !== undefined && result.rowCount === 0) {
    const active = await client.query(
      `SELECT 1 FROM app_users WHERE organization_id = $1 AND firebase_uid = $2
       AND lower(email) = lower($3) AND status = 'active' AND deleted_at IS NULL`,
      [input.organizationId, input.firebaseUid, input.email],
    );
    if (active.rowCount !== 1) {
    throw new StaffInviteError(
      "failed-precondition",
      "The signed-in identity does not match an active invitation.",
    );
    }
  }
  for (const row of result.rows) {
    await publishStaffLifecycle(client, row, "user.invite.accepted", input.firebaseUid, row.id);
  }
  await client.query("COMMIT");
  return result.rowCount ?? 0;
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  }
}

async function publishStaffLifecycle(client: PoolClient, row: Record<string, any>,
  commandType: string, firebaseUid: string, actorUserId: string) {
  const operationId = randomUUID();
  const user = {
    id: row.id, organizationId: row.organization_id, firebaseUid: row.firebase_uid,
    email: row.email, displayName: row.display_name, status: row.status, version: row.version,
    invitedAt: row.invited_at?.toISOString() ?? null,
    activatedAt: row.activated_at?.toISOString() ?? null,
    createdAt: row.created_at.toISOString(), updatedAt: row.updated_at.toISOString(),
    deletedAt: row.deleted_at?.toISOString() ?? null,
  };
  await client.query(
    `INSERT INTO audit_logs(id, organization_id, actor_user_id, firebase_uid,
      operation_id, action, entity_type, entity_id, metadata_json, occurred_at, created_at)
     VALUES ($1, $2, $3, $4, $5, $6, 'app_user', $7, $8, now(), now())`,
    [randomUUID(), row.organization_id, actorUserId, firebaseUid, operationId,
      commandType, row.id, {status: row.status}],
  );
  await client.query(
    `INSERT INTO change_feed(organization_id, branch_id, aggregate_type, aggregate_id,
      operation_id, change_type, version, payload_json, occurred_at, created_at)
     VALUES ($1, NULL, 'app_user', $2, $3, 'upsert', $4, $5, now(), now())`,
    [row.organization_id, row.id, operationId, row.version,
      {schemaVersion: 1, commandType, actorUserId, commandPayload: {}, result: {user}}],
  );
}

async function requireOrganizationPermission(
  client: PoolClient,
  firebaseUid: string,
  organizationId: string,
  permission: string,
): Promise<void> {
  const access = await client.query(
    `SELECT 1 FROM app_users au
     JOIN user_role_assignments ura ON ura.user_id = au.id
       AND ura.organization_id = au.organization_id
       AND ura.branch_id IS NULL AND ura.revoked_at IS NULL
     JOIN roles r ON r.id = ura.role_id AND r.organization_id = ura.organization_id
       AND r.is_active = true AND r.deleted_at IS NULL
     JOIN role_permissions rp ON rp.role_id = r.id AND rp.permission_code = $3
     WHERE au.firebase_uid = $1 AND au.organization_id = $2
       AND au.status = 'active' AND au.deleted_at IS NULL
     LIMIT 1`,
    [firebaseUid, organizationId, permission],
  );
  if (access.rowCount !== 1) {
    throw new StaffInviteError(
      "permission-denied",
      `An organization-wide ${permission} role is required.`,
    );
  }
}
