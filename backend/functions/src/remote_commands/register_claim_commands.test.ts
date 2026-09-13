import assert from "node:assert/strict";
import test from "node:test";
import type {PoolClient} from "pg";

import {applyRegisterClaimCommand} from "./register_claim_commands.js";
import type {AuthorizedCommand} from "./command_types.js";

type RegisterState = {
  id: string;
  assignedDeviceId: string | null;
  version: number;
};

type ClaimState = {
  id: string;
  requestedRegisterId: string;
  resolvedRegisterId: string | null;
  deviceId: string;
  status: string;
  version: number;
};

test("the first server-accepted claim wins and the losing attempt is retained", async () => {
  const database = new RegisterClaimDatabase([
    {id: "register-a", assignedDeviceId: null, version: 0},
  ]);

  const accepted = await applyRegisterClaimCommand(
    database.client,
    claimCommand("claim-a", "register-a", "device-a", 0),
  );
  const rejected = await applyRegisterClaimCommand(
    database.client,
    claimCommand("claim-b", "register-a", "device-b", 0),
  );

  assert.equal(database.registers.get("register-a")?.assignedDeviceId, "device-a");
  assert.equal((accepted.registerClaim as {status: string}).status, "accepted");
  assert.equal((rejected.registerClaim as {status: string}).status, "rejected");
  assert.equal(database.claims.get("claim-b")?.status, "rejected");
});

test("manager resolution reserves an unclaimed register and is replay-safe", async () => {
  const database = new RegisterClaimDatabase([
    {id: "register-a", assignedDeviceId: "device-a", version: 1},
    {id: "register-b", assignedDeviceId: null, version: 0},
  ]);
  database.claims.set("claim-b", {
    id: "claim-b",
    requestedRegisterId: "register-a",
    resolvedRegisterId: null,
    deviceId: "device-b",
    status: "rejected",
    version: 0,
  });
  const command = resolveCommand("claim-b", "register-b");

  const resolved = await applyRegisterClaimCommand(database.client, command);
  const replay = await applyRegisterClaimCommand(database.client, command);

  assert.equal(database.registers.get("register-b")?.assignedDeviceId, "device-b");
  assert.deepEqual(resolved.directive, {
    type: "rebase_unsynced_claim_chain",
    claimId: "claim-b",
    fromRegisterId: "register-a",
    targetRegisterId: "register-b",
    deviceId: "device-b",
  });
  assert.equal(replay.duplicateResolution, true);
});

class RegisterClaimDatabase {
  constructor(registers: RegisterState[]) {
    for (const register of registers) this.registers.set(register.id, register);
  }

  readonly registers = new Map<string, RegisterState>();
  readonly claims = new Map<string, ClaimState>();

  readonly client = {
    query: async (sql: string, values: unknown[]) => this.query(sql, values),
  } as unknown as PoolClient;

  private async query(sql: string, values: unknown[]) {
    const normalized = sql.replace(/\s+/g, " ").trim();
    if (normalized.startsWith("SELECT id FROM devices")) {
      return {rowCount: 1, rows: [{id: values[0]}]};
    }
    if (normalized.startsWith("SELECT assigned_device_id, version FROM registers")) {
      const register = this.registers.get(values[0] as string);
      return register === undefined ? {rowCount: 0, rows: []} : {
        rowCount: 1,
        rows: [{
          assigned_device_id: register.assignedDeviceId,
          version: register.version,
        }],
      };
    }
    if (normalized.startsWith("SELECT id FROM registers WHERE organization_id")) {
      const deviceId = values[1] as string;
      const register = [...this.registers.values()].find(
        (candidate) => candidate.assignedDeviceId === deviceId,
      );
      return register === undefined ? {rowCount: 0, rows: []} : {
        rowCount: 1,
        rows: [{id: register.id}],
      };
    }
    if (normalized.startsWith("UPDATE registers SET assigned_device_id = $4")) {
      const register = this.registers.get(values[0] as string)!;
      const deviceId = values[3] as string;
      if (register.assignedDeviceId !== null && register.assignedDeviceId !== deviceId) {
        return {rowCount: 0, rows: []};
      }
      if (register.assignedDeviceId !== deviceId) register.version += 1;
      register.assignedDeviceId = deviceId;
      return {rowCount: 1, rows: [registerRow(register)]};
    }
    if (normalized.startsWith("INSERT INTO register_claims") &&
        normalized.includes("'rejected'")) {
      const claim: ClaimState = {
        id: values[0] as string,
        requestedRegisterId: values[3] as string,
        resolvedRegisterId: null,
        deviceId: values[4] as string,
        status: "rejected",
        version: 0,
      };
      this.claims.set(claim.id, claim);
      return {rowCount: 1, rows: [claimRow(claim)]};
    }
    if (normalized.startsWith("INSERT INTO register_claims")) {
      const claim: ClaimState = {
        id: values[0] as string,
        requestedRegisterId: values[3] as string,
        resolvedRegisterId: null,
        deviceId: values[4] as string,
        status: "accepted",
        version: 0,
      };
      this.claims.set(claim.id, claim);
      return {rowCount: 1, rows: [claimRow(claim)]};
    }
    if (normalized.startsWith("SELECT id, branch_id, requested_register_id")) {
      const claim = this.claims.get(values[0] as string);
      return claim === undefined ? {rowCount: 0, rows: []} : {
        rowCount: 1,
        rows: [{...claimRow(claim), branch_id: "branch"}],
      };
    }
    if (normalized.startsWith("SELECT version FROM registers")) {
      const register = this.registers.get(values[0] as string);
      if (register === undefined || register.assignedDeviceId !== null) {
        return {rowCount: 0, rows: []};
      }
      return {rowCount: 1, rows: [{version: register.version}]};
    }
    if (normalized.startsWith("SELECT 1 FROM registers")) {
      const deviceId = values[1] as string;
      const found = [...this.registers.values()].some(
        (register) => register.assignedDeviceId === deviceId,
      );
      return {rowCount: found ? 1 : 0, rows: found ? [{"?column?": 1}] : []};
    }
    if (normalized.startsWith("UPDATE register_claims SET resolved_register_id")) {
      const claim = this.claims.get(values[0] as string)!;
      claim.resolvedRegisterId = values[3] as string;
      claim.status = "resolved";
      claim.version += 1;
      return {rowCount: 1, rows: [
        {...claimRow(claim), resolved_by_user_id: values[5]},
      ]};
    }
    throw new Error(`Unexpected query: ${normalized}`);
  }
}

function registerRow(register: RegisterState) {
  return {
    id: register.id,
    assigned_device_id: register.assignedDeviceId,
    version: register.version,
  };
}

function claimRow(claim: ClaimState) {
  return {
    id: claim.id,
    requested_register_id: claim.requestedRegisterId,
    resolved_register_id: claim.resolvedRegisterId,
    device_id: claim.deviceId,
    status: claim.status,
    version: claim.version,
  };
}

function claimCommand(
  claimId: string,
  registerId: string,
  deviceId: string,
  expectedVersion: number,
): AuthorizedCommand {
  return {
    firebaseUid: "firebase-cashier",
    actorUserId: "cashier",
    operationId: claimId,
    organizationId: "organization",
    branchId: "branch",
    commandType: "register.claim",
    aggregateType: "register_claim",
    aggregateId: claimId,
    permissions: new Set(["registers.claim"]),
    payload: {claimId, registerId, deviceId, expectedVersion},
  };
}

function resolveCommand(claimId: string, targetRegisterId: string): AuthorizedCommand {
  return {
    firebaseUid: "firebase-manager",
    actorUserId: "manager",
    operationId: "resolve-claim-b",
    organizationId: "organization",
    branchId: "branch",
    commandType: "register.claim.resolve",
    aggregateType: "register_claim",
    aggregateId: claimId,
    permissions: new Set(["registers.manage"]),
    payload: {claimId, targetRegisterId},
  };
}
