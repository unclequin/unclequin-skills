# TypeScript and JavaScript: Functional First

Arrays have `filter`, `map`, and `reduce`, so the composed form reads like the sentence. Tagged unions and literal types make a closed set of states, and the compiler checks the transition table's shape. Array methods don't fuse: each one is a full pass that allocates a new array.

## Compose: a pipeline of named predicates

```ts
export type YearMonth = { readonly year: number; readonly month: number }; // month 1–12

export type Order = {
  readonly id: string;
  readonly total: number; // integer cents
  readonly paidIn?: YearMonth;
  readonly refunded: boolean;
};

const paidIn = (m: YearMonth) => (o: Order): boolean =>
  o.paidIn !== undefined && o.paidIn.year === m.year && o.paidIn.month === m.month;

const isRefunded = (o: Order): boolean => o.refunded;

const sum = (xs: readonly number[]): number => xs.reduce((a, b) => a + b, 0);

/** Revenue for a month is the sum of the totals of orders paid in that month,
 *  except refunded ones. A refund at any time excludes the order. */
export function monthlyRevenue(orders: readonly Order[], m: YearMonth): number {
  return sum(orders.filter(paidIn(m)).filter((o) => !isRefunded(o)).map((o) => o.total));
}
```

Money is integer cents. Float sums depend on order, which breaks the spec-equals-derived check (see `derivation.md`). For amounts beyond `Number.MAX_SAFE_INTEGER`, use `bigint`.

## Derive: group instead of rescanning

```ts
/** Spec: twelve passes, one per month. */
export function revenueByMonthSpec(orders: readonly Order[], year: number): number[] {
  return Array.from({ length: 12 }, (_, i) => monthlyRevenue(orders, { year, month: i + 1 }));
}

/** Derived from revenueByMonthSpec by grouping instead of rescanning. */
export function revenueByMonth(orders: readonly Order[], year: number): number[] {
  const out = new Array<number>(12).fill(0);
  for (const o of orders) {
    if (o.paidIn?.year === year && !isRefunded(o)) out[o.paidIn.month - 1] += o.total;
  }
  return out;
}
```

Fusing `filter(...).filter(...).map(...)` into one loop is the next derivation, only when a profile shows those arrays matter.

## State machine: a table as data

```ts
export const states = ["draft", "paid", "shipped", "cancelled"] as const;
export const events = ["pay", "ship", "cancel"] as const;
export type State = (typeof states)[number];
export type Event = (typeof events)[number];

/** The whole lifecycle. A pair that isn't here is illegal. */
export const transitions: Readonly<Record<State, Partial<Record<Event, State>>>> = {
  draft: { pay: "paid", cancel: "cancelled" },
  paid: { ship: "shipped", cancel: "cancelled" },
  shipped: {},
  cancelled: {},
};

export type Result = { ok: true; state: State } | { ok: false; state: State; error: string };

export function step(state: State, event: Event): Result {
  const next = transitions[state][event];
  return next === undefined
    ? { ok: false, state, error: `cannot ${event} an order that is ${state}` }
    : { ok: true, state: next };
}

/** Folds step over events and stops at the first illegal one. */
export function replay(start: State, history: readonly Event[]): Result {
  let result: Result = { ok: true, state: start };
  for (const event of history) {
    result = step(result.state, event);
    if (!result.ok) return result;
  }
  return result;
}
```

`Record<State, ...>` makes the compiler require an entry for every state, so a new state can't be forgotten. Use string-literal unions and `as const` arrays rather than `enum`: they work with Node's type stripping and give a list to generate test events from.

When states carry data (only an issued policy has a term), make `State` a tagged union (`{ status: "issued"; term: number } | ...`). Keep a table keyed by `status` for which moves are legal, and compute the new data in `step`.

## Types: sets of values, sets of messages

```ts
// Before: three flags and two optional fields allow 2³ combinations of flags,
// each with or without an amount and a tracking number. Four are legal.
export type OrderRecord = {
  paid: boolean;
  shipped: boolean;
  cancelled: boolean;
  amount?: number;
  tracking?: string;
};
```

```ts
/** An amount in integer cents, greater than zero. Only parseAmount makes one. */
export type Amount = number & { readonly __brand: "Amount" };

export type Parsed<T> = { ok: true; value: T } | { ok: false; error: string };

/** Parses raw input at the boundary; the core takes only Amount. */
export function parseAmount(raw: string): Parsed<Amount> {
  const n = Number(raw);
  return /^[0-9]+$/.test(raw) && Number.isSafeInteger(n) && n > 0
    ? { ok: true, value: n as Amount }
    : { ok: false, error: `invalid amount: ${JSON.stringify(raw)}` };
}
```

The brand exists only in the type checker: an `Amount` is a plain number at run time, but a bare `number` can't be passed where an `Amount` is expected. `parseAmount` is the one place that asserts it.

```ts
// After: one type per state, each holding only its own data.
export type Draft = { readonly status: "draft"; readonly id: string };
export type Paid = { readonly status: "paid"; readonly id: string; readonly amount: Amount };
export type Shipped = {
  readonly status: "shipped";
  readonly id: string;
  readonly amount: Amount;
  readonly tracking: string;
};
export type Cancelled = { readonly status: "cancelled"; readonly id: string };
export type Order = Draft | Paid | Shipped | Cancelled;

/** The amount to refund on cancellation: only money that was taken. */
export function refundDue(order: Order): number {
  switch (order.status) {
    case "draft":
    case "cancelled":
      return 0;
    case "paid":
    case "shipped":
      return order.amount;
    default:
      return assertNever(order);
  }
}
```

`assertNever` takes a `never`, so adding a fifth state is a compile error in every `switch` that doesn't handle it. TypeScript's unions are untagged, so give every case a literal `status` field to switch on.

```ts
/** The messages a state accepts, read from the transition table. */
export function accepts(state: State): Event[] {
  return events.filter((e) => transitions[state][e] !== undefined);
}

// Typestate: each operation takes only the state that accepts it.
export const pay = (o: Draft, amount: Amount): Paid => ({ status: "paid", id: o.id, amount });
export const ship = (o: Paid, tracking: string): Shipped => ({ ...o, status: "shipped", tracking });
export const cancel = (o: Draft | Paid): Cancelled => ({ status: "cancelled", id: o.id });
```

`Event` is the set of messages the lifecycle understands, and `accepts` reads the subset for one state from the table instead of keeping a second list. The typed operations make the same table a compile-time check for code that drives an order step by step: `ship(draft, ...)` doesn't type-check. Events that arrive as data, from a queue or a database, still go through `step`.

## Check: properties

With `fast-check`, which works with `node:test`, Vitest, and Jest:

```ts
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
```

```ts
test("a state accepts exactly the events step allows", () => {
  for (const state of states) {
    assert.deepEqual(accepts(state), events.filter((e) => step(state, e).ok));
  }
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
```

`@ts-expect-error` turns "this must not compile" into a test: `tsc` fails if the line ever starts type-checking.

Without a dependency, a seeded generator in a plain test works the same way. It just doesn't shrink:

```ts
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
```

## Tooling

- `tsc --strict` for type checking. Node 22.18+ runs `.ts` directly with type stripping, so stay with erasable syntax: no `enum`, `namespace`, or parameter properties. Type stripping doesn't check types: if `tsc` isn't available, say that the code ran but wasn't type-checked.
- Measure before deriving: `node --cpu-prof`, or `performance.now()` around a realistic input. In browsers, use the Performance panel.
