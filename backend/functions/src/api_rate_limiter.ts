import {createHash} from "node:crypto";
import {PoolClient} from "pg";

export type RateLimitInput = {
  firebaseUid: string;
  scope: string;
  maximumRequests: number;
  windowSeconds: number;
  units?: number;
};

export class RateLimitExceededError extends Error {
  constructor(readonly retryAfterSeconds: number) {
    super("The request rate limit was exceeded.");
  }
}

export async function enforceRateLimit(
  client: PoolClient,
  input: RateLimitInput,
): Promise<void> {
  if (!/^[a-z0-9_-]{1,80}$/.test(input.scope) ||
      !input.firebaseUid || input.firebaseUid.length > 1024 ||
      !Number.isSafeInteger(input.maximumRequests) || input.maximumRequests < 1 ||
      input.maximumRequests > 1_000_000_000 ||
      !Number.isSafeInteger(input.windowSeconds) || input.windowSeconds < 1 ||
      input.windowSeconds > 86400 * 31 ||
      !Number.isSafeInteger(input.units ?? 1) || (input.units ?? 1) < 1 ||
      (input.units ?? 1) > input.maximumRequests) {
    throw new Error("The server rate-limit policy is invalid.");
  }

  const identityHash = createHash("sha256")
    .update(input.firebaseUid)
    .digest("hex");
  const result = await client.query<{
    request_count: number;
    retry_after_seconds: number;
  }>(
    `
      WITH current_window AS (
        SELECT to_timestamp(
          floor(extract(epoch FROM clock_timestamp()) / $3) * $3
        ) AS started_at
      )
      INSERT INTO api_rate_limit_windows (
        identity_hash, scope, window_started_at, request_count, expires_at
      )
      SELECT $1, $2, started_at, $4,
        started_at + make_interval(secs => $3)
      FROM current_window
      ON CONFLICT (identity_hash, scope, window_started_at)
      DO UPDATE SET request_count = least($5 + 1,
        api_rate_limit_windows.request_count + $4)
      RETURNING request_count,
        greatest(1, ceil(extract(epoch FROM (expires_at - clock_timestamp()))))::integer
          AS retry_after_seconds
    `,
    [identityHash, input.scope, input.windowSeconds, input.units ?? 1,
      input.maximumRequests],
  );
  const row = result.rows[0];
  if (row === undefined) {
    throw new Error("The rate-limit counter was not returned.");
  }

  if (row.request_count === (input.units ?? 1)) {
    await client.query(
      `DELETE FROM api_rate_limit_windows
       WHERE ctid IN (
         SELECT ctid FROM api_rate_limit_windows
         WHERE expires_at < clock_timestamp() - interval '1 day'
         ORDER BY expires_at
         LIMIT 100
       )`,
    );
  }

  if (row.request_count > input.maximumRequests) {
    throw new RateLimitExceededError(row.retry_after_seconds);
  }
}
