import assert from "node:assert/strict";
import { test } from "node:test";
import { events, revenueByMonth, revenueByMonthSpec, step, transitions, type State } from "./orders.ts";
import fc from "fast-check";

const order = fc.record({
  id: fc.string(),
  total: fc.nat(1000),
  refunded: fc.boolean(),
  paidIn: fc.option(fc.record({ year: fc.integer({ min: 2024, max: 2025 }), month: fc.integer({ min: 1, max: 12 }) }), { nil: undefined }),
});

test("revenueByMonth equals its spec", () => {
  fc.assert(fc.property(fc.array(order, { maxLength: 20 }), (orders) => {
    assert.deepEqual(revenueByMonth(orders, 2024), revenueByMonthSpec(orders, 2024));
  }));
});

test("lifecycle invariants hold over random event sequences", () => {
  fc.assert(fc.property(fc.array(fc.constantFrom(...events), { maxLength: 8 }), (history) => {
    let state: State = "draft";
    for (const event of history) {
      const result = step(state, event);
      assert.equal(result.ok, transitions[state][event] !== undefined);
      if (!result.ok) assert.equal(result.state, state);
      state = result.state;
    }
  }));
});
