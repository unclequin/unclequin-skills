// The code shown in skills/functional-first/references/languages/typescript.md.
// scripts/check-examples.py checks that the two stay the same.

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
