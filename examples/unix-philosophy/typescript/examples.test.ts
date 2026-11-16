import assert from "node:assert/strict";
import { test } from "node:test";
import {
  ValidationError, countLines, fetchOpaque, fetchTransparent, partner, portOrThrow, portSilent,
  retryPartner, shippingFee, signup, welcomed,
} from "./examples.ts";

test("signup parses, creates, then mails; bad input stops before the mail", async () => {
  assert.equal((await signup({ body: { email: "a@b.c" } })).email, "a@b.c");
  assert.deepEqual(welcomed, ["a@b.c"]);
  await assert.rejects(signup({ body: {} }), ValidationError);
  assert.deepEqual(welcomed, ["a@b.c"]);
});

test("countLines works on any async iterable", async () => {
  async function* lines() { yield "a"; yield "b"; }
  assert.equal(await countLines(lines()), 2);
});

test("withRetry gives up after maxAttempts", async () => {
  Object.assign(partner, { calls: 0, failures: 2 });
  await retryPartner();
  assert.equal(partner.calls, 3);
  Object.assign(partner, { calls: 0, failures: 3 });
  await assert.rejects(retryPartner(), /partner is down/);
});

test("the transparent error keeps context and cause; the opaque one loses both", () => {
  assert.throws(() => fetchOpaque("missing"), (e: Error) => e.message === "failed" && e.cause === undefined);
  assert.throws(
    () => fetchTransparent("missing"),
    (e: Error) => e.message === "fetch order missing" && (e.cause as Error).message === "404",
  );
});

test("a bad PORT is NaN when silent and an error when checked", () => {
  process.env.PORT = "eighty";
  assert.ok(Number.isNaN(portSilent()));
  assert.throws(() => portOrThrow(), /invalid PORT "eighty"/);
  process.env.PORT = "8080";
  assert.equal(portOrThrow(), 8080);
});

test("shippingFee reads the table and falls back to 100", () => {
  assert.deepEqual(["BKK", "NORTH", "MARS"].map(shippingFee), [40, 80, 100]);
});
