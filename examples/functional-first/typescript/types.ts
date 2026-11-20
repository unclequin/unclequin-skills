import { events, transitions, type Event, type State } from "./orders.ts";

// Before: three flags and two optional fields allow 2³ combinations of flags,
// each with or without an amount and a tracking number. Four are legal.
export type OrderRecord = {
  paid: boolean;
  shipped: boolean;
  cancelled: boolean;
  amount?: number;
  tracking?: string;
};

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

function assertNever(x: never): never {
  throw new Error(`unhandled case: ${JSON.stringify(x)}`);
}

/** The messages a state accepts, read from the transition table. */
export function accepts(state: State): Event[] {
  return events.filter((e) => transitions[state][e] !== undefined);
}

// Typestate: each operation takes only the state that accepts it.
export const pay = (o: Draft, amount: Amount): Paid => ({ status: "paid", id: o.id, amount });
export const ship = (o: Paid, tracking: string): Shipped => ({ ...o, status: "shipped", tracking });
/** Draft | Paid is the set of states that accept cancel. Law: cancelling keeps the order's id. */
export const cancel = (o: Draft | Paid): Cancelled => ({ status: "cancelled", id: o.id });
