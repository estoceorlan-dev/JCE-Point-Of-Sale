import {PoolClient} from "pg";

export class SnapshotCapacityError extends Error {
  constructor() {super("The snapshot exceeds the configured capacity; use a paginated workflow.");}
}

export async function boundedSnapshotQuery(client: PoolClient, sql: string, values: unknown[]) {
  const limit = Number(process.env.JCE_SNAPSHOT_MAX_ROWS ?? 5000);
  if (!Number.isSafeInteger(limit) || limit < 1 || limit > 10000) {
    throw new Error("Invalid server snapshot row policy.");
  }
  const result = await client.query(`${sql} LIMIT $${values.length + 1}`, [...values, limit + 1]);
  // Never silently truncate an authoritative snapshot used to replace caches.
  if (result.rows.length > limit) throw new SnapshotCapacityError();
  return result;
}

export function ensureSnapshotFits<T>(snapshot: T): T {
  const bytes = Number(process.env.JCE_SNAPSHOT_MAX_BYTES ?? 2 * 1024 * 1024);
  if (!Number.isSafeInteger(bytes) || bytes < 1024 || bytes > 8 * 1024 * 1024) {
    throw new Error("Invalid server snapshot byte policy.");
  }
  if (Buffer.byteLength(JSON.stringify(snapshot)) > bytes) throw new SnapshotCapacityError();
  return snapshot;
}
