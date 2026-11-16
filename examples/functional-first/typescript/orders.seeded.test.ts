import assert from "node:assert/strict";
import { test } from "node:test";
import { revenueByMonth, revenueByMonthSpec, type Order } from "./orders.ts";

function randomOrders(int: (n: number) => number): Order[] {
  return Array.from({ length: int(20) }, (_, i) => ({
    id: String(i),
    total: int(1000),
    refunded: int(4) === 0,
    ...(int(3) > 0 ? { paidIn: { year: 2024 + int(2), month: 1 + int(12) } } : {}),
  }));
}

// Small seeded generator (mulberry32), so failures can be reproduced.
function rng(seed: number) {
  return (n: number): number => {
    seed = (seed + 0x6d2b79f5) | 0;
    let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return (((t ^ (t >>> 14)) >>> 0) % n);
  };
}

test("revenueByMonth equals its spec", () => {
  const int = rng(42);
  for (let i = 0; i < 1000; i++) {
    const orders = randomOrders(int); // small totals, 2 years, some unpaid
    assert.deepEqual(revenueByMonth(orders, 2024), revenueByMonthSpec(orders, 2024), `case ${i}`);
  }
});
