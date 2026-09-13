import {PoolClient} from "pg";

import {
  AuthorizedCommand,
  CommandResult,
  RemoteCommandError,
  optionalString,
  requiredInteger,
  requiredString,
} from "./command_types";
import {consumeRegisterClaimGrant} from "../manager_action_grants";

type ClaimRow = {
  id: string;
  branch_id: string;
  requested_register_id: string;
  resolved_register_id: string | null;
  device_id: string;
  status: string;
  version: number;
};

export async function applyRegisterClaimCommand(
  client: PoolClient,
  command: AuthorizedCommand,
): Promise<CommandResult> {
  if (command.commandType === "register.claim") {
    return claimRegister(client, command);
  }
  if (command.commandType === "register.claim.resolve") {
    return resolveRegisterClaim(client, command);
  }
  if (command.commandType === "register.release") {
    return releaseRegister(client, command);
  }
  throw new RemoteCommandError(
    "invalid-argument",
    `Unsupported register claim command: ${command.commandType}.`,
  );
}

async function claimRegister(
  client: PoolClient,
  command: AuthorizedCommand,
): Promise<CommandResult> {
  const claimId = requiredString(command.payload, "claimId");
  const registerId = requiredString(command.payload, "registerId");
  const deviceId = requiredString(command.payload, "deviceId");
  const expectedVersion = requiredInteger(command.payload, "expectedVersion");
  if (claimId !== command.aggregateId || expectedVersion < 0) {
    throw new RemoteCommandError("invalid-argument", "The register claim is invalid.");
  }

  const device = await client.query(
    `SELECT id FROM devices
     WHERE id = $1 AND organization_id = $2 AND branch_id = $3
       AND disabled_at IS NULL
     FOR UPDATE`,
    [deviceId, command.organizationId, command.branchId],
  );
  if (device.rowCount !== 1) {
    throw new RemoteCommandError("not-found", "The active branch installation does not exist.");
  }

  const register = await client.query<{
    assigned_device_id: string | null;
    version: number;
  }>(
    `SELECT assigned_device_id, version FROM registers
     WHERE id = $1 AND organization_id = $2 AND branch_id = $3
       AND is_active = true AND deleted_at IS NULL
     FOR UPDATE`,
    [registerId, command.organizationId, command.branchId],
  );
  if (register.rowCount !== 1) {
    throw new RemoteCommandError("not-found", "The active register does not exist.");
  }

  const deviceProjection = await client.query<{id: string}>(
    `SELECT id FROM registers
     WHERE organization_id = $1 AND assigned_device_id = $2
       AND deleted_at IS NULL
     LIMIT 1`,
    [command.organizationId, deviceId],
  );
  const projectedRegisterId = deviceProjection.rows[0]?.id ?? null;
  const rejection = register.rows[0].version !== expectedVersion ?
    {
      code: "register_version_changed",
      message: "The register changed before this provisional claim reached the server.",
    } : register.rows[0].assigned_device_id !== null &&
      register.rows[0].assigned_device_id !== deviceId ?
      {
        code: "register_already_claimed",
        message: "Another installation claimed this register first.",
      } : projectedRegisterId !== null && projectedRegisterId !== registerId ?
        {
          code: "installation_already_claimed",
          message: "This installation is already assigned to another register.",
        } : null;

  if (rejection !== null) {
    const rejected = await client.query(
      `INSERT INTO register_claims (
         id, organization_id, branch_id, requested_register_id, device_id,
         claimed_by_user_id, status, rejection_code, rejection_message,
         version, created_at, updated_at
       ) VALUES ($1, $2, $3, $4, $5, $6, 'rejected', $7, $8, 0, now(), now())
       RETURNING id, requested_register_id, device_id, status, rejection_code,
         rejection_message, version, created_at, updated_at`,
      [
        claimId,
        command.organizationId,
        command.branchId,
        registerId,
        deviceId,
        command.actorUserId,
        rejection.code,
        rejection.message,
      ],
    );
    return {registerClaim: rejected.rows[0]};
  }

  const updatedRegister = await client.query(
    `UPDATE registers SET
       assigned_device_id = $4,
       assigned_by_user_id = $5,
       assigned_at = COALESCE(assigned_at, now()),
       version = CASE WHEN assigned_device_id = $4 THEN version ELSE version + 1 END,
       updated_at = now()
     WHERE id = $1 AND organization_id = $2 AND branch_id = $3
     RETURNING id, assigned_device_id, version`,
    [
      registerId,
      command.organizationId,
      command.branchId,
      deviceId,
      command.actorUserId,
    ],
  );
  const accepted = await client.query(
    `INSERT INTO register_claims (
       id, organization_id, branch_id, requested_register_id, device_id,
       claimed_by_user_id, status, version, created_at, updated_at
     ) VALUES ($1, $2, $3, $4, $5, $6, 'accepted', 0, now(), now())
     RETURNING id, requested_register_id, device_id, status, version,
       created_at, updated_at`,
    [
      claimId,
      command.organizationId,
      command.branchId,
      registerId,
      deviceId,
      command.actorUserId,
    ],
  );
  return {registerClaim: accepted.rows[0], register: updatedRegister.rows[0]};
}

async function resolveRegisterClaim(
  client: PoolClient,
  command: AuthorizedCommand,
): Promise<CommandResult> {
  const claimId = requiredString(command.payload, "claimId");
  const targetRegisterId = requiredString(command.payload, "targetRegisterId");
  if (claimId !== command.aggregateId) {
    throw new RemoteCommandError("invalid-argument", "Register claim IDs do not match.");
  }
  const claimResult = await client.query<ClaimRow>(
    `SELECT id, branch_id, requested_register_id, resolved_register_id,
       device_id, status, version
     FROM register_claims
     WHERE id = $1 AND organization_id = $2 AND branch_id = $3
     FOR UPDATE`,
    [claimId, command.organizationId, command.branchId],
  );
  if (claimResult.rowCount !== 1) {
    throw new RemoteCommandError("not-found", "The rejected register claim does not exist.");
  }
  const claim = claimResult.rows[0];
  if (claim.status === "resolved") {
    if (claim.resolved_register_id !== targetRegisterId) {
      throw new RemoteCommandError("already-exists", "The claim was resolved to another register.");
    }
    return {registerClaim: claim, duplicateResolution: true};
  }
  if (claim.status !== "rejected") {
    throw new RemoteCommandError("failed-precondition", "Only a rejected claim can be reassigned.");
  }
  const resolvingManagerUserId = command.permissions.has("registers.manage") ?
    command.actorUserId : await consumeRegisterClaimGrant(client, command);

  const device = await client.query(
    `SELECT id FROM devices
     WHERE id = $1 AND organization_id = $2 AND branch_id = $3
       AND disabled_at IS NULL
     FOR UPDATE`,
    [claim.device_id, command.organizationId, command.branchId],
  );
  if (device.rowCount !== 1) {
    throw new RemoteCommandError(
      "not-found",
      "The affected installation is no longer active in this branch.",
    );
  }
  const target = await client.query<{version: number}>(
    `SELECT version FROM registers
     WHERE id = $1 AND organization_id = $2 AND branch_id = $3
       AND assigned_device_id IS NULL AND is_active = true AND deleted_at IS NULL
     FOR UPDATE`,
    [targetRegisterId, command.organizationId, command.branchId],
  );
  if (target.rowCount !== 1) {
    throw new RemoteCommandError(
      "failed-precondition",
      "The target register is no longer active and unclaimed.",
    );
  }
  const otherProjection = await client.query(
    `SELECT 1 FROM registers
     WHERE organization_id = $1 AND assigned_device_id = $2
       AND deleted_at IS NULL
     LIMIT 1`,
    [command.organizationId, claim.device_id],
  );
  if (otherProjection.rowCount !== 0) {
    throw new RemoteCommandError(
      "failed-precondition",
      "The installation already owns another server-confirmed register.",
    );
  }

  const updatedRegister = await client.query(
    `UPDATE registers SET assigned_device_id = $4, assigned_by_user_id = $5,
       assigned_at = now(), version = version + 1, updated_at = now()
     WHERE id = $1 AND organization_id = $2 AND branch_id = $3
       AND assigned_device_id IS NULL
     RETURNING id, assigned_device_id, version`,
    [
      targetRegisterId,
      command.organizationId,
      command.branchId,
      claim.device_id,
      resolvingManagerUserId,
    ],
  );
  if (updatedRegister.rowCount !== 1) {
    throw new RemoteCommandError("aborted", "The target register was claimed concurrently.");
  }
  const resolved = await client.query(
    `UPDATE register_claims SET resolved_register_id = $4, status = 'resolved',
       resolution_operation_id = $5, resolved_by_user_id = $6,
       resolved_at = now(), version = version + 1, updated_at = now()
     WHERE id = $1 AND organization_id = $2 AND branch_id = $3
     RETURNING id, requested_register_id, resolved_register_id, device_id,
       status, resolved_by_user_id, resolved_at, version, updated_at`,
    [
      claimId,
      command.organizationId,
      command.branchId,
      targetRegisterId,
      command.operationId,
      resolvingManagerUserId,
    ],
  );
  return {
    registerClaim: resolved.rows[0],
    register: updatedRegister.rows[0],
    directive: {
      type: "rebase_unsynced_claim_chain",
      claimId,
      fromRegisterId: claim.requested_register_id,
      targetRegisterId,
      deviceId: claim.device_id,
    },
  };
}

async function releaseRegister(
  client: PoolClient,
  command: AuthorizedCommand,
): Promise<CommandResult> {
  const registerId = requiredString(command.payload, "registerId");
  const requestedDeviceId = optionalString(command.payload, "deviceId");
  if (registerId !== command.aggregateId) {
    throw new RemoteCommandError("invalid-argument", "Register IDs do not match.");
  }
  const register = await client.query<{assigned_device_id: string | null}>(
    `SELECT assigned_device_id FROM registers
     WHERE id = $1 AND organization_id = $2 AND branch_id = $3
       AND deleted_at IS NULL
     FOR UPDATE`,
    [registerId, command.organizationId, command.branchId],
  );
  if (register.rowCount !== 1) {
    throw new RemoteCommandError("not-found", "The register does not exist.");
  }
  const deviceId = register.rows[0].assigned_device_id;
  if (requestedDeviceId !== null && deviceId !== requestedDeviceId) {
    throw new RemoteCommandError("aborted", "The register assignment changed. Refresh and retry.");
  }
  const openShift = await client.query(
    `SELECT 1 FROM shifts
     WHERE organization_id = $1 AND branch_id = $2 AND register_id = $3
       AND status = 'open'
     LIMIT 1`,
    [command.organizationId, command.branchId, registerId],
  );
  if (openShift.rowCount !== 0) {
    throw new RemoteCommandError("failed-precondition", "Close the register shift before release.");
  }
  const updated = await client.query(
    `UPDATE registers SET assigned_device_id = NULL,
       assigned_by_user_id = NULL, assigned_at = NULL,
       version = version + 1, updated_at = now()
     WHERE id = $1 AND organization_id = $2 AND branch_id = $3
     RETURNING id, assigned_device_id, version`,
    [registerId, command.organizationId, command.branchId],
  );
  if (deviceId !== null) {
    await client.query(
      `UPDATE register_claims SET status = 'released',
         released_by_user_id = $4, released_at = now(),
         version = version + 1, updated_at = now()
       WHERE organization_id = $1 AND branch_id = $2 AND device_id = $3
         AND status IN ('accepted', 'resolved')`,
      [command.organizationId, command.branchId, deviceId, command.actorUserId],
    );
  }
  return {register: updated.rows[0], releasedDeviceId: deviceId};
}
