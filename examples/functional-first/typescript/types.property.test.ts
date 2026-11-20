import assert from "node:assert/strict";
import { test } from "node:test";
import fc from "fast-check";
import { events, states, step } from "./orders.ts";
import { accepts, cancel, parseAmount, pay, ship, type Draft } from "./types.ts";

test("a state accepts exactly the events step allows", () => {
  for (const state of states) {
    assert.deepEqual(accepts(state), events.filter((e) => step(state, e).ok));
  }
});

test("parseAmount accepts exactly the positive whole numbers of cents", () => {
  fc.assert(fc.property(fc.string(), (raw) => {
    const parsed = parseAmount(raw);
    const n = Number(raw);
    assert.equal(parsed.ok, /^[0-9]+$/.test(raw) && Number.isSafeInteger(n) && n > 0);
  }));
  fc.assert(fc.property(fc.integer({ min: 1, max: Number.MAX_SAFE_INTEGER }), (n) => {
    assert.deepEqual(parseAmount(String(n)), { ok: true, value: n });
  }));
});

test("a draft can't be shipped", () => {
  const draft: Draft = { status: "draft", id: "o1" };
  const amount = parseAmount("500");
  assert.ok(amount.ok);
  assert.equal(ship(pay(draft, amount.value), "T1").status, "shipped");
  // @ts-expect-error a Draft is not a Paid, so ship rejects it at compile time
  const illegal = () => ship(draft, "T1");
  assert.equal(typeof illegal, "function");
});

test("cancelling keeps the order's id", () => {
  fc.assert(fc.property(fc.string(), fc.integer({ min: 1, max: Number.MAX_SAFE_INTEGER }), (id, cents) => {
    const amount = parseAmount(String(cents));
    assert.ok(amount.ok);
    const draft: Draft = { status: "draft", id };
    for (const order of [draft, pay(draft, amount.value)]) {
      assert.equal(cancel(order).id, id);
    }
  }));
});
