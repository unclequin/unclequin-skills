// The code shown in skills/unix-philosophy/references/languages/typescript.md.
// scripts/check-examples.py checks that the two stay the same.

type Signup = { email: string };
type User = { id: string; email: string };
type Order = { id: string };
type Req = { body: unknown };

class ValidationError extends Error {}

function parseSignup(body: unknown): Signup {
  if (typeof body !== "object" || body === null || !("email" in body) || typeof body.email !== "string") {
    throw new ValidationError("email is required");
  }
  return { email: body.email };
}

const welcomed: string[] = [];
const users = { create: async (signup: Signup): Promise<User> => ({ id: "u1", email: signup.email }) };
const mailer = { sendWelcome: async (user: User): Promise<void> => void welcomed.push(user.email) };
const app = { post(_path: string, _handler: (req: Req, res: unknown) => Promise<void>): void {} };

// Before: one handler, four jobs
app.post("/signup", async (req, res) => { /* parse + validate + insert + email */ });

async function signup(req: Req): Promise<User> {
  // After
  const signup = parseSignup(req.body);        // returns Signup or throws ValidationError
  const user = await users.create(signup);
  await mailer.sendWelcome(user);
  return user;
}

// Composable: works with files, HTTP bodies, test fixtures
async function countLines(lines: AsyncIterable<string>): Promise<number> {
  let n = 0;
  for await (const _ of lines) n++;
  return n;
}

// Simple: ask for only what you use
type UserGetter = { get(id: string): Promise<User> };
function makeInvoice(users: UserGetter, id: string) { /* ... */ }

type RetryPolicy = { maxAttempts: number; backoffMs: number };

// The mechanism the reference file leaves as a comment.
async function withRetry<T>(policy: RetryPolicy, fn: () => Promise<T>): Promise<T> {
  for (let attempt = 1; ; attempt++) {
    try {
      return await fn();
    } catch (e) {
      if (attempt >= policy.maxAttempts) throw e;
      await new Promise((resolve) => setTimeout(resolve, policy.backoffMs));
    }
  }
}

const partner = { calls: 0, failures: 0 };
async function callPartner(): Promise<string> {
  partner.calls++;
  if (partner.calls <= partner.failures) throw new Error("partner is down");
  return "ok";
}

async function retryPartner(): Promise<void> {
  await withRetry({ maxAttempts: 3, backoffMs: 200 }, () => callPartner());
}

function fetchOrder(orderId: string): Order {
  if (orderId === "missing") throw new Error("404");
  return { id: orderId };
}

function fetchOpaque(orderId: string): Order {
  try { return fetchOrder(orderId); }
  // Opaque: loses the original error
  catch (e) { throw new Error("failed"); }
}

function fetchTransparent(orderId: string): Order {
  try { return fetchOrder(orderId); }
  // Transparent: context plus the original cause
  catch (e) {
    throw new Error(`fetch order ${orderId}`, { cause: e });
  }
}

function portSilent(): number {
  // Silent failure: port becomes NaN, discovered later
  const port = Number(process.env.PORT);
  return port;
}

function portOrThrow(): number {
  // Fail fast at startup (or validate the whole config with a schema library such as zod)
  const port = Number(process.env.PORT);
  if (!Number.isInteger(port)) throw new Error(`invalid PORT "${process.env.PORT}"`);
  return port;
}

const SHIPPING_FEES: Record<string, number> = { BKK: 40, CENTRAL: 60, NORTH: 80 };
const shippingFee = (zone: string) => SHIPPING_FEES[zone] ?? 100;

export {
  ValidationError, countLines, fetchOpaque, fetchTransparent, makeInvoice, partner, portOrThrow,
  portSilent, retryPartner, shippingFee, signup, welcomed,
};
export type { UserGetter };
