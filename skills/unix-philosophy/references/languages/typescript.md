# TypeScript / JavaScript Idioms for the Unix Philosophy

Applies to Node.js, browser, and frontend frameworks. Prefer TypeScript with `strict` mode on.

## Modularity: small modules, small functions

One module, one responsibility. Prefer named exports of plain functions over large classes. In React and similar frameworks, split components that both fetch data and render complex UI: a hook or loader for data, a component for display.

```ts
// Before: one handler, four jobs
app.post("/signup", async (req, res) => { /* parse + validate + insert + email */ });

// After
const signup = parseSignup(req.body);        // returns Signup or throws ValidationError
const user = await users.create(signup);
await mailer.sendWelcome(user);
```

## Composition: accept iterables, streams, and functions

```ts
// Hard to compose: only works with a file path
async function countLines(path: string): Promise<number>

// Composable: works with files, HTTP bodies, test fixtures
async function countLines(lines: AsyncIterable<string>): Promise<number> {
  let n = 0;
  for await (const _ of lines) n++;
  return n;
}
```

Reach for `Iterable`, `AsyncIterable`, Node `Readable`/`Writable`, Web Streams, and plain functions as arguments.

## Simplicity: structural types, narrow contracts

TypeScript is structurally typed, so you rarely need declared interfaces with one implementation. Define the narrow shape a function needs.

```ts
// Over-engineered
interface IUserService { create(); get(); update(); delete(); list(); }
class UserServiceImpl implements IUserService { /* ... */ }

// Simple: ask for only what you use
type UserGetter = { get(id: string): Promise<User> };
function makeInvoice(users: UserGetter, id: string) { /* ... */ }
```

Avoid deep class hierarchies and dependency-injection frameworks unless the project already standardized on one.

## Separation: policy as parameters or config

```ts
type RetryPolicy = { maxAttempts: number; backoffMs: number };

async function withRetry<T>(policy: RetryPolicy, fn: () => Promise<T>): Promise<T> { /* mechanism */ }

await withRetry({ maxAttempts: 3, backoffMs: 200 }, () => callPartner());
```

## Transparency and Repair: errors with cause, fail fast

```ts
// Opaque: loses the original error
catch (e) { throw new Error("failed"); }

// Transparent: context plus the original cause
catch (e) {
  throw new Error(`fetch order ${orderId}`, { cause: e });
}
```

```ts
// Silent failure: port becomes NaN, discovered later
const port = Number(process.env.PORT);

// Fail fast at startup (or validate the whole config with a schema library such as zod)
const port = Number(process.env.PORT);
if (!Number.isInteger(port)) throw new Error(`invalid PORT "${process.env.PORT}"`);
```

Red flags: empty `catch {}`, `.catch(() => {})`, floating promises without `await` or handling, `any` used to silence type errors, `// @ts-ignore` without a reason. Turn on `@typescript-eslint/no-floating-promises`.

## Representation: lookup objects and maps

```ts
const SHIPPING_FEES: Record<string, number> = { BKK: 40, CENTRAL: 60, NORTH: 80 };
const shippingFee = (zone: string) => SHIPPING_FEES[zone] ?? 100;
```

Discriminated unions with exhaustive `switch` (checked with `never`) are the typed version of this rule.

## Least Surprise: JS/TS conventions

- Async functions return Promises; don't mix callbacks and Promises in one API.
- Don't mutate arguments unless the name says so.
- camelCase for values, PascalCase for types and components.
- Format with Prettier, lint with ESLint.

## Silence

CLIs write results with `process.stdout.write`, diagnostics with `console.error`, and set `process.exitCode = 1` on failure. Remove leftover `console.log` debugging.

## Generation

`openapi-typescript` or `orval` for API clients, `graphql-codegen`, `prisma generate` or `kysely-codegen` for database types, `ts-proto` for protobuf.

## Optimization

Measure first: Chrome DevTools Performance tab, `node --cpu-prof`, `clinic.js`, `tinybench` or `vitest bench`. For frontend, check bundle size (`source-map-explorer`) and React Profiler before memoizing.

## Extensibility

Version API payloads and events (`{ version: 1, type, data }`); add optional fields rather than changing existing ones.
