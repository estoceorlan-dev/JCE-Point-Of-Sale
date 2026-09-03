import {PoolClient} from "pg";

export type RemoteCommandInput = {
  firebaseUid: string;
  operationId: string;
  organizationId: string;
  branchId: string;
  commandType: string;
  aggregateType: string;
  aggregateId: string;
  deviceId?: string | null;
  payload: Record<string, unknown>;
};

export type AuthorizedCommand = RemoteCommandInput & {
  actorUserId: string;
  permissions: Set<string>;
};

export type CommandResult = Record<string, unknown>;

export type CommandHandler = (
  client: PoolClient,
  command: AuthorizedCommand,
) => Promise<CommandResult>;

export class RemoteCommandError extends Error {
  constructor(
    readonly code:
      | "invalid-argument"
      | "permission-denied"
      | "not-found"
      | "already-exists"
      | "failed-precondition"
      | "aborted",
    message: string,
  ) {
    super(message);
  }
}

export function asObject(value: unknown, field: string): Record<string, unknown> {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw new RemoteCommandError("invalid-argument", `${field} must be an object.`);
  }
  return value as Record<string, unknown>;
}

export function requiredString(
  value: Record<string, unknown>,
  field: string,
): string {
  const candidate = value[field];
  if (typeof candidate !== "string" || candidate.trim().length === 0) {
    throw new RemoteCommandError("invalid-argument", `${field} is required.`);
  }
  return candidate.trim();
}

export function optionalString(
  value: Record<string, unknown>,
  field: string,
): string | null {
  const candidate = value[field];
  if (candidate === undefined || candidate === null) return null;
  if (typeof candidate !== "string") {
    throw new RemoteCommandError("invalid-argument", `${field} must be a string.`);
  }
  const normalized = candidate.trim();
  return normalized.length === 0 ? null : normalized;
}

export function requiredInteger(
  value: Record<string, unknown>,
  field: string,
): number {
  const candidate = value[field];
  if (typeof candidate !== "number" || !Number.isSafeInteger(candidate)) {
    throw new RemoteCommandError("invalid-argument", `${field} must be an integer.`);
  }
  return candidate;
}

export function optionalInteger(
  value: Record<string, unknown>,
  field: string,
): number | null {
  const candidate = value[field];
  if (candidate === undefined || candidate === null) return null;
  return requiredInteger(value, field);
}

export function requiredBoolean(
  value: Record<string, unknown>,
  field: string,
): boolean {
  const candidate = value[field];
  if (typeof candidate !== "boolean") {
    throw new RemoteCommandError("invalid-argument", `${field} must be a boolean.`);
  }
  return candidate;
}

export function requiredArray(
  value: Record<string, unknown>,
  field: string,
): unknown[] {
  const candidate = value[field];
  if (!Array.isArray(candidate)) {
    throw new RemoteCommandError("invalid-argument", `${field} must be a list.`);
  }
  return candidate;
}

export function optionalTimestamp(
  value: Record<string, unknown>,
  field: string,
): Date | null {
  const candidate = optionalString(value, field);
  if (candidate === null) return null;
  const parsed = new Date(candidate);
  if (Number.isNaN(parsed.valueOf())) {
    throw new RemoteCommandError("invalid-argument", `${field} is invalid.`);
  }
  return parsed;
}

export function normalizeSearch(value: string): string {
  return value.trim().toUpperCase().replace(/[^A-Z0-9]/g, "");
}

export function roundDivide(numerator: number, denominator: number): number {
  if (!Number.isSafeInteger(numerator)) {
    throw new RemoteCommandError("invalid-argument", "A monetary calculation overflowed.");
  }
  return Math.floor((numerator + Math.floor(denominator / 2)) / denominator);
}
