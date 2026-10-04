import {createHash, randomUUID} from "node:crypto";
import {PoolClient} from "pg";

import {
  RemoteCommandError,
  RemoteCommandInput,
  requiredString,
} from "./remote_commands/command_types";

export async function issueRegisterClaimResolutionGrant(
  client: PoolClient,
  input: {
    managerFirebaseUid: string;
    organizationId: string;
    branchId: string;
    conflictId: string;
    targetRegisterId: string;
    deviceId: string;
    requestedByUserId: string;
    nonce: string;
  },
): Promise<Record<string, unknown>> {
  if (input.nonce.length < 24 || input.nonce.length > 256) {
    throw new RemoteCommandError("invalid-argument", "The action nonce is invalid.");
  }
  await client.query("BEGIN");
  try {
    await client.query("SELECT pg_advisory_xact_lock(hashtextextended($1, 0))",
      [`access-administration:${input.organizationId}`]);
    const manager = await client.query<{id: string}>(
      `SELECT au.id
       FROM app_users au
       INNER JOIN organizations o ON o.id = au.organization_id
         AND o.is_active = true AND o.deleted_at IS NULL
       INNER JOIN branches b ON b.organization_id = o.id AND b.id = $3
         AND b.is_active = true AND b.deleted_at IS NULL
       INNER JOIN user_role_assignments ura
         ON ura.user_id = au.id AND ura.organization_id = au.organization_id
         AND (ura.branch_id IS NULL OR ura.branch_id = $3)
         AND ura.revoked_at IS NULL
       INNER JOIN roles r
         ON r.id = ura.role_id AND r.organization_id = ura.organization_id
         AND r.is_active = true AND r.deleted_at IS NULL
       INNER JOIN role_permissions rp
         ON rp.role_id = r.id AND rp.permission_code = 'registers.manage'
       WHERE au.firebase_uid = $1 AND au.organization_id = $2
         AND au.status = 'active' AND au.deleted_at IS NULL
       LIMIT 1 FOR SHARE OF au, o, b`,
      [input.managerFirebaseUid, input.organizationId, input.branchId],
    );
    if (manager.rowCount !== 1) {
      throw new RemoteCommandError(
        "permission-denied",
        "A manager with registers.manage is required.",
      );
    }
    const binding = await client.query(
      `SELECT 1 FROM register_claims claim
       INNER JOIN registers target
         ON target.id = $4 AND target.organization_id = claim.organization_id
         AND target.branch_id = claim.branch_id
         AND target.is_active = true AND target.deleted_at IS NULL
         AND target.assigned_device_id IS NULL
       INNER JOIN app_users requester
         ON requester.id = $6 AND requester.organization_id = claim.organization_id
         AND requester.status = 'active' AND requester.deleted_at IS NULL
       INNER JOIN devices device
         ON device.id = claim.device_id
         AND device.organization_id = claim.organization_id
         AND device.branch_id = claim.branch_id AND device.disabled_at IS NULL
       WHERE claim.id = $1 AND claim.organization_id = $2
         AND claim.branch_id = $3 AND claim.device_id = $5
         AND claim.status = 'rejected'
       FOR UPDATE OF claim, target`,
      [
        input.conflictId,
        input.organizationId,
        input.branchId,
        input.targetRegisterId,
        input.deviceId,
        input.requestedByUserId,
      ],
    );
    if (binding.rowCount !== 1) {
      throw new RemoteCommandError(
        "failed-precondition",
        "The conflict, installation, or target register changed.",
      );
    }
    const grantId = randomUUID();
    const expiresAt = new Date(Date.now() + 5 * 60 * 1000);
    await client.query(
      `INSERT INTO manager_action_grants (
         id, organization_id, branch_id, requested_by_user_id,
         manager_user_id, action, conflict_id, target_register_id,
         device_id, nonce_hash, expires_at, created_at
       ) VALUES ($1, $2, $3, $4, $5, 'register.claim.resolve', $6, $7,
         $8, $9, $10, now())`,
      [
        grantId,
        input.organizationId,
        input.branchId,
        input.requestedByUserId,
        manager.rows[0].id,
        input.conflictId,
        input.targetRegisterId,
        input.deviceId,
        hashNonce(input.nonce),
        expiresAt,
      ],
    );
    await client.query("COMMIT");
    return {
      grantId,
      managerUserId: manager.rows[0].id,
      expiresAt: expiresAt.toISOString(),
    };
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  }
}

export async function hasValidRegisterClaimGrant(
  client: PoolClient,
  input: RemoteCommandInput,
  actorUserId: string,
): Promise<boolean> {
  const grantId = input.payload.managerGrantId;
  const nonce = input.payload.managerGrantNonce;
  const targetRegisterId = input.payload.targetRegisterId;
  if (typeof grantId !== "string" || typeof nonce !== "string" ||
      typeof targetRegisterId !== "string") return false;
  const result = await client.query(
    `SELECT 1 FROM manager_action_grants
     WHERE id = $1 AND organization_id = $2 AND branch_id = $3
       AND requested_by_user_id = $4 AND action = 'register.claim.resolve'
       AND conflict_id = $5 AND target_register_id = $6
       AND device_id = $7 AND nonce_hash = $8
       AND ${currentManagerAuthority}
       AND ((consumed_at IS NULL AND expires_at > now())
         OR consumed_by_operation_id = $9)`,
    [
      grantId,
      input.organizationId,
      input.branchId,
      actorUserId,
      input.aggregateId,
      targetRegisterId,
      input.deviceId,
      hashNonce(nonce),
      input.operationId,
    ],
  );
  return result.rowCount === 1;
}

export async function consumeRegisterClaimGrant(
  client: PoolClient,
  command: {organizationId: string; branchId: string; actorUserId: string;
    operationId: string;
    aggregateId: string; deviceId?: string | null; payload: Record<string, unknown>},
): Promise<string> {
  const grantId = requiredString(command.payload, "managerGrantId");
  const nonce = requiredString(command.payload, "managerGrantNonce");
  const targetRegisterId = requiredString(command.payload, "targetRegisterId");
  const result = await client.query<{manager_user_id: string}>(
    `UPDATE manager_action_grants SET consumed_at = now(),
       consumed_by_operation_id = $9
     WHERE id = $1 AND organization_id = $2 AND branch_id = $3
       AND requested_by_user_id = $4 AND action = 'register.claim.resolve'
       AND conflict_id = $5 AND target_register_id = $6
       AND device_id = $7 AND nonce_hash = $8
       AND ${currentManagerAuthority}
       AND consumed_at IS NULL AND expires_at > now()
     RETURNING manager_user_id`,
    [
      grantId,
      command.organizationId,
      command.branchId,
      command.actorUserId,
      command.aggregateId,
      targetRegisterId,
      command.deviceId,
      hashNonce(nonce),
      command.operationId,
    ],
  );
  if (result.rowCount !== 1) {
    throw new RemoteCommandError(
      "permission-denied",
      "The manager action grant is invalid, expired, or already used.",
    );
  }
  return result.rows[0].manager_user_id;
}

function hashNonce(nonce: string): string {
  return createHash("sha256").update(nonce).digest("hex");
}

// Fixed SQL, never client input. Recheck authority at both authorization and
// consumption so an outstanding grant cannot outlive a role/user revocation.
const currentManagerAuthority = `EXISTS (
  SELECT 1 FROM app_users manager
  JOIN organizations o ON o.id = manager.organization_id
    AND o.is_active = true AND o.deleted_at IS NULL
  JOIN branches b ON b.organization_id = o.id
    AND b.id = manager_action_grants.branch_id
    AND b.is_active = true AND b.deleted_at IS NULL
  JOIN user_role_assignments assignment ON assignment.user_id = manager.id
    AND assignment.organization_id = manager.organization_id
    AND (assignment.branch_id IS NULL OR assignment.branch_id = b.id)
    AND assignment.revoked_at IS NULL
  JOIN roles role ON role.id = assignment.role_id
    AND role.organization_id = manager.organization_id
    AND role.is_active = true AND role.deleted_at IS NULL
  JOIN role_permissions permission ON permission.role_id = role.id
    AND permission.permission_code = 'registers.manage'
  WHERE manager.id = manager_action_grants.manager_user_id
    AND manager.organization_id = manager_action_grants.organization_id
    AND manager.status = 'active' AND manager.deleted_at IS NULL
)`;
