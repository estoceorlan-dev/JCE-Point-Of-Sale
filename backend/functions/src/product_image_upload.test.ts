import assert from "node:assert/strict";
import test from "node:test";
import {decodeImageUpload, maximumImageBytes, reserveImageBytes, stageAuthorizedImage} from "./product_image_upload";
import {createHash} from "node:crypto";
import {authorizeCommand} from "./remote_commands/command_authorization";

test("image finalization uses products.manage rather than an unsupported command prefix", async () => {
  for (const permissions of [[], ["products.manage"]]) {
    const client = {async query(sql: string) {
      return sql.includes("actor_user_id") ? {rowCount: 1,
        rows: [{actor_user_id: "user", permission_codes: permissions}]} : {rows: [], rowCount: 0};
    }};
    const command = authorizeCommand(client as never, {firebaseUid: "user",
      organizationId: "org", branchId: "branch", operationId: "image-operation",
      aggregateId: "image", aggregateType: "product_image", commandType: "product_image.finalize",
      payload: {}});
    if (permissions.length) assert.equal((await command).actorUserId, "user");
    else await assert.rejects(command, (error) => (error as {code: string}).code === "permission-denied");
  }
});

test("image bytes are bounded and declared type must match the signature", () => {
  const png = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);
  assert.deepEqual(decodeImageUpload(png.toString("base64"), "image/png"), png);
  assert.throws(() => decodeImageUpload(png.toString("base64"), "image/jpeg"));
  for (const value of [null, "", "!!!!", "YQ", " YQ==", "YQ==\n",
    Buffer.alloc(maximumImageBytes + 1).toString("base64")]) {
    assert.throws(() => decodeImageUpload(value, "image/png"));
  }
  assert.throws(() => decodeImageUpload(Buffer.from("<script>").toString("base64"), "image/png"));
});

test("image byte quota is reserved atomically before storage work", async () => {
  const calls: unknown[][] = [];
  const client = {async query(sql: string, values?: unknown[]) {
    if (sql.includes("INSERT INTO")) calls.push(values!);
    return {rows: [{request_count: 32, retry_after_seconds: 80}]};
  }};
  await reserveImageBytes(client as never, "org", 16);
  assert.equal(calls[0][3], 16);
  assert.equal(calls[0][4], 100 * 1024 * 1024);
  assert.equal(calls[0][1], "image_bytes_daily");
});

test("server upload is create-only and retries accept only identical scoped content", async () => {
  const bytes = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);
  const input = {firebaseUid: "user", organizationId: "org", branchId: "branch",
    productId: "product", aggregateId: "image", aggregateType: "product_image",
    operationId: "operation", commandType: "product_image.finalize", payload: {},
    stagingPath: "users/user/product-images/image"};
  let exists = false;
  let digest = createHash("sha256").update(bytes).digest("hex");
  const file = {
    async save(actual: Buffer, options: {preconditionOpts: {ifGenerationMatch: number}}) {
      assert.deepEqual(actual, bytes);
      assert.equal(options.preconditionOpts.ifGenerationMatch, 0);
      if (exists) throw {code: 412};
      exists = true;
    },
    async getMetadata() {return [{metadata: {sha256: digest, organizationId: "org", productId: "product"}}];},
  };
  const storage = {bucket: () => ({file: (name: string) => {
    assert.equal(name, input.stagingPath); return file;
  }})};
  await stageAuthorizedImage(input, bytes, "image/png", storage as never);
  await stageAuthorizedImage(input, bytes, "image/png", storage as never);
  digest = "different";
  await assert.rejects(stageAuthorizedImage(input, bytes, "image/png", storage as never),
    (error) => (error as {code: string}).code === "already-exists");
});
