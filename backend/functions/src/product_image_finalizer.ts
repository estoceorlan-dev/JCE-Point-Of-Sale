import {createHash, randomUUID} from "node:crypto";
import {getStorage} from "firebase-admin/storage";
import {PoolClient} from "pg";

import {authorizeCommand} from "./remote_commands/command_authorization";
import {
  CommandResult,
  RemoteCommandError,
  RemoteCommandInput,
} from "./remote_commands/command_types";

export type ProductImageFinalization = RemoteCommandInput & {
  productId: string;
  stagingPath: string;
};

export async function findPriorImageFinalization(
  client: PoolClient,
  input: ProductImageFinalization,
): Promise<CommandResult | null> {
  await authorizeCommand(client, input);
  const prior = await client.query<{result_json: CommandResult}>(
    `SELECT result_json FROM processed_operations
     WHERE organization_id = $1 AND operation_id = $2`,
    [input.organizationId, input.operationId],
  );
  if (prior.rowCount === 1) return prior.rows[0].result_json;
  const product = await client.query(
    `SELECT 1 FROM products
     WHERE id = $1 AND organization_id = $2 AND is_active = true AND deleted_at IS NULL`,
    [input.productId, input.organizationId],
  );
  if (product.rowCount !== 1) {
    throw new RemoteCommandError("not-found", "The active product does not exist.");
  }
  const imageCollision = await client.query(
    `SELECT 1 FROM product_images
     WHERE id = $1 AND (organization_id <> $2 OR product_id <> $3)`,
    [input.aggregateId, input.organizationId, input.productId],
  );
  if (imageCollision.rowCount !== 0) {
    throw new RemoteCommandError("permission-denied", "The image ID belongs to another product.");
  }
  return null;
}

export async function copyProductImage(
  input: ProductImageFinalization,
): Promise<{storagePath: string; remoteUrl: string}> {
  const expectedStagingPath = `users/${input.firebaseUid}/product-images/${input.aggregateId}`;
  if (input.stagingPath !== expectedStagingPath) {
    throw new RemoteCommandError("permission-denied", "The staging image path is invalid.");
  }
  const bucket = getStorage().bucket();
  const source = bucket.file(input.stagingPath);
  const [exists] = await source.exists();
  if (!exists) throw new RemoteCommandError("not-found", "The staged product image does not exist.");
  const storagePath = `organizations/${input.organizationId}/products/${input.productId}/${input.aggregateId}`;
  const destination = bucket.file(storagePath);
  await source.copy(destination);
  const tokenHash = createHash("sha256").update(input.operationId).digest("hex");
  const downloadToken = [
    tokenHash.slice(0, 8),
    tokenHash.slice(8, 12),
    tokenHash.slice(12, 16),
    tokenHash.slice(16, 20),
    tokenHash.slice(20, 32),
  ].join("-");
  await destination.setMetadata({metadata: {firebaseStorageDownloadTokens: downloadToken}});
  const remoteUrl = `https://firebasestorage.googleapis.com/v0/b/${encodeURIComponent(bucket.name)}/o/${encodeURIComponent(storagePath)}?alt=media&token=${downloadToken}`;
  return {storagePath, remoteUrl};
}

export async function persistProductImageFinalization(
  client: PoolClient,
  input: ProductImageFinalization,
  uploaded: {storagePath: string; remoteUrl: string},
): Promise<CommandResult> {
  await client.query("BEGIN");
  try {
    await client.query(
      "SELECT pg_advisory_xact_lock(hashtextextended($1, 0))",
      [`${input.organizationId}|${input.operationId}`],
    );
    const command = await authorizeCommand(client, input);
    const prior = await client.query<{result_json: CommandResult}>(
      `SELECT result_json FROM processed_operations
       WHERE organization_id = $1 AND operation_id = $2`,
      [command.organizationId, command.operationId],
    );
    if (prior.rowCount === 1) {
      await client.query("COMMIT");
      return prior.rows[0].result_json;
    }
    const product = await client.query(
      `SELECT id FROM products WHERE id = $1 AND organization_id = $2 AND deleted_at IS NULL`,
      [input.productId, input.organizationId],
    );
    if (product.rowCount !== 1) throw new RemoteCommandError("not-found", "The product does not exist.");
    const image = await client.query(
      `
        INSERT INTO product_images (
          id, organization_id, product_id, storage_path, remote_url,
          upload_status, sort_order, version, created_at, updated_at, deleted_at
        ) VALUES ($1, $2, $3, $4, $5, 'uploaded', 0, 0, now(), now(), NULL)
        ON CONFLICT (id) DO UPDATE SET
          storage_path = EXCLUDED.storage_path,
          remote_url = EXCLUDED.remote_url,
          upload_status = 'uploaded',
          version = product_images.version + 1,
          updated_at = now(),
          deleted_at = NULL
        WHERE product_images.organization_id = EXCLUDED.organization_id
          AND product_images.product_id = EXCLUDED.product_id
        RETURNING id, product_id, storage_path, remote_url, upload_status, version, updated_at
      `,
      [input.aggregateId, input.organizationId, input.productId, uploaded.storagePath, uploaded.remoteUrl],
    );
    if (image.rowCount !== 1) throw new RemoteCommandError("permission-denied", "The image belongs to another product.");
    const result: CommandResult = {productImage: image.rows[0]};
    await client.query(
      `INSERT INTO audit_logs (
        id, organization_id, branch_id, actor_user_id, firebase_uid,
        operation_id, action, entity_type, entity_id, metadata_json,
        occurred_at, created_at
      ) VALUES ($1, $2, $3, $4, $5, $6, 'product_image.finalize',
        'product_image', $7, $8, now(), now())`,
      [randomUUID(), input.organizationId, input.branchId, command.actorUserId, input.firebaseUid, input.operationId, input.aggregateId, {productId: input.productId}],
    );
    await client.query(
      `INSERT INTO change_feed (
        organization_id, branch_id, aggregate_type, aggregate_id,
        operation_id, change_type, version, payload_json, occurred_at, created_at
      ) VALUES ($1, $2, 'product_image', $3, $4, 'upsert', $5, $6, now(), now())`,
      [
        input.organizationId,
        null,
        input.aggregateId,
        input.operationId,
        image.rows[0].version,
        {
          schemaVersion: 1,
          commandType: "product_image.finalize",
          actorUserId: command.actorUserId,
          commandPayload: command.payload,
          result,
        },
      ],
    );
    await client.query(
      `INSERT INTO processed_operations (
        organization_id, operation_id, branch_id, command_type,
        aggregate_type, aggregate_id, actor_user_id, firebase_uid,
        result_json, processed_at
      ) VALUES ($1, $2, $3, 'product_image.finalize', 'product_image', $4, $5, $6, $7, now())`,
      [input.organizationId, input.operationId, input.branchId, input.aggregateId, command.actorUserId, input.firebaseUid, result],
    );
    await client.query("COMMIT");
    return result;
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  }
}

export async function deleteStagingImage(stagingPath: string): Promise<void> {
  await getStorage().bucket().file(stagingPath).delete({ignoreNotFound: true});
}
