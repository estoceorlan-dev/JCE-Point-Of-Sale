import {
  AuthTypes,
  Connector,
  IpAddressTypes,
} from "@google-cloud/cloud-sql-connector";
import {Pool, PoolClient} from "pg";

let pool: Pool | undefined;
let connector: Connector | undefined;
let activeConfigKey: string | undefined;
let poolCreatedAt = 0;
let poolInitialization: Promise<void> | undefined;

// Cloud Run can suspend background timers between requests. Renew before the
// one-hour IAM database credential expires instead of relying only on the
// connector's scheduled refresh.
export const maximumPoolAgeMilliseconds = 45 * 60 * 1000;

export type DatabaseConnectionConfig = {
  instanceConnectionName: string;
  database: string;
  user: string;
};

export async function withDatabase<T>(
  config: DatabaseConnectionConfig,
  operation: (client: PoolClient) => Promise<T>,
): Promise<T> {
  const configKey = [
    config.instanceConnectionName,
    config.database,
    config.user,
  ].join("|");

  let selectedPool = await ensurePool(config, configKey);
  let client: PoolClient;
  try {
    client = await selectedPool.connect();
  } catch (error) {
    if (!isDatabaseAuthenticationFailure(error)) throw error;
    selectedPool = await ensurePool(config, configKey, selectedPool);
    client = await selectedPool.connect();
  }

  try {
    return await operation(client);
  } finally {
    client.release();
  }
}

async function ensurePool(
  config: DatabaseConnectionConfig,
  configKey: string,
  failedPool?: Pool,
): Promise<Pool> {
  const poolIsFresh = isDatabasePoolFresh({
    poolExists: pool !== undefined,
    activeConfigKey,
    requestedConfigKey: configKey,
    createdAt: poolCreatedAt,
  });
  if (poolIsFresh && (failedPool === undefined || pool !== failedPool)) {
    return pool!;
  }

  if (poolInitialization !== undefined) {
    await poolInitialization;
    return ensurePool(config, configKey, failedPool);
  }

  // A concurrent request may already have replaced the pool that failed for
  // this request. In that case, reuse the newer pool instead of rebuilding it.
  if (failedPool !== undefined && pool !== failedPool && poolIsFresh) {
    return pool!;
  }

  poolInitialization = rebuildPool(config, configKey);
  try {
    await poolInitialization;
  } finally {
    poolInitialization = undefined;
  }
  if (pool === undefined) {
    throw new Error("The database connection pool could not be initialized.");
  }
  return pool;
}

async function rebuildPool(
  config: DatabaseConnectionConfig,
  configKey: string,
): Promise<void> {
  const previousPool = pool;
  const previousConnector = connector;
  pool = undefined;
  connector = undefined;
  activeConfigKey = undefined;
  poolCreatedAt = 0;

  await previousPool?.end();
  previousConnector?.close();

  const nextConnector = new Connector();
  try {
    const connectionOptions = await nextConnector.getOptions({
      instanceConnectionName: config.instanceConnectionName,
      ipType: IpAddressTypes.PUBLIC,
      authType: AuthTypes.IAM,
    });
    const nextPool = new Pool({
      ...connectionOptions,
      database: config.database,
      user: config.user,
      max: 5,
      idleTimeoutMillis: 30_000,
      connectionTimeoutMillis: 10_000,
    });
    connector = nextConnector;
    pool = nextPool;
    activeConfigKey = configKey;
    poolCreatedAt = Date.now();
  } catch (error) {
    nextConnector.close();
    throw error;
  }
}

export function isDatabasePoolFresh(input: {
  poolExists: boolean;
  activeConfigKey?: string;
  requestedConfigKey: string;
  createdAt: number;
  now?: number;
}): boolean {
  return input.poolExists && input.activeConfigKey === input.requestedConfigKey &&
    (input.now ?? Date.now()) - input.createdAt < maximumPoolAgeMilliseconds;
}

export function isDatabaseAuthenticationFailure(error: unknown): boolean {
  return typeof error === "object" && error !== null &&
    "code" in error && error.code === "28000";
}
