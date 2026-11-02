# Rust Idioms for the Unix Philosophy

Rust's type system, `Result`, and exhaustive `match` make Repair, Representation, and Least Surprise natural. The main risk is the opposite of Simplicity: over-generic code, trait gymnastics, and lifetime puzzles. Follow the Rust API Guidelines, `rustfmt`, and `clippy`.

## Modularity: small modules, small functions

One module, one responsibility, with a minimal `pub` surface. Keep `main.rs` thin; put logic in `lib.rs` so it can be tested and reused.

```rust
// main.rs only wires parts together
let signup = parse_signup(&body)?;          // -> Result<Signup, ValidationError>
let user = users.create(&signup).await?;
mailer.send_welcome(&user).await?;
```

## Composition: accept general standard types

```rust
use std::io::{self, BufRead};

// Hard to compose: only works with files
fn count_lines(path: &Path) -> io::Result<usize>

// Composable: works with stdin, files, sockets, and &[u8] in tests
fn count_lines<R: BufRead>(reader: R) -> io::Result<usize> {
    let mut n = 0;
    for line in reader.lines() {
        line?;
        n += 1;
    }
    Ok(n)
}

// count_lines(io::stdin().lock())
// count_lines(BufReader::new(File::open(path)?))
// count_lines(&b"a\nb\n"[..])
```

Also prefer `&str` over `&String`, `&[T]` over `&Vec<T>`, `impl AsRef<Path>`, `impl IntoIterator<Item = T>`, and returning `impl Iterator` so callers can chain adapters.

## Simplicity: concrete first, generics when needed

```rust
// Over-engineered: a trait with one implementation, plus a boxed factory
trait UserService { fn get(&self, id: &str) -> Result<User>; /* ...8 more */ }
struct UserServiceImpl { /* ... */ }

// Simple: a concrete struct; add a narrow trait when a second implementation
// or a test double is actually needed
struct UserStore { pool: PgPool }
```

- Prefer an `enum` over `Box<dyn Trait>` when the set of variants is closed.
- A `.clone()` that removes a lifetime puzzle is usually the right trade (Economy). Optimize it away only if a profile says so.
- Avoid macros where a function works.

## Separation: policy as parameters

```rust
pub struct RetryPolicy {
    pub max_attempts: u32,
    pub backoff: Duration,
}

pub async fn with_retry<T, E, F, Fut>(policy: &RetryPolicy, f: F) -> Result<T, E>
where
    F: FnMut() -> Fut,
    Fut: Future<Output = Result<T, E>>,
{ /* mechanism only */ }
```

## Transparency and Repair: `?` with context, no hidden panics

Applications typically use `anyhow` (or `eyre`) for context; libraries define typed errors with `thiserror` and keep the `#[source]`.

```rust
use anyhow::Context;

// Opaque
let order = client.fetch(order_id).await?;

// Transparent: what failed and on what, original error preserved
let order = client
    .fetch(order_id)
    .await
    .with_context(|| format!("fetch order {order_id}"))?;
```

```rust
// Fail fast at startup
let port: u16 = std::env::var("PORT")
    .context("PORT is required")?
    .parse()
    .context("PORT must be a number from 0 to 65535")?;
```

Red flags: `.unwrap()` or `.expect()` outside tests and truly impossible cases; `let _ = fallible();`; `.ok()` or `.unwrap_or_default()` that throws away a real error; `panic!` for expected failures. Clippy lints `unwrap_used` and `expect_used` can enforce this in libraries.

## Representation: enums, `match`, and types that forbid bad states

```rust
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum Zone { Bkk, Central, North, Other }

impl Zone {
    fn fee(self) -> u32 {
        match self {
            Zone::Bkk => 40,
            Zone::Central => 60,
            Zone::North => 80,
            Zone::Other => 100,
        }
    }
}
```

Use newtypes (`struct OrderId(String)`) and parse-don't-validate constructors so invalid values can't exist past the boundary.

## Least Surprise: Rust conventions

- Naming per the API Guidelines: `as_` (cheap borrow), `to_` (expensive conversion), `into_` (consumes self), `new` for constructors, `try_` for fallible versions.
- Implement standard traits callers expect: `Debug`, `Display`, `Clone`, `Default`, `From`/`TryFrom`, `PartialEq`.
- Resources clean up in `Drop`; don't require manual close calls.
- Run `cargo fmt` and `cargo clippy -- -D warnings`.

## Silence

Results go to stdout with `println!`, diagnostics to stderr with `eprintln!`, and `main` returns `ExitCode` or `Result` so failures exit non-zero. Use `tracing` with levels for services. Remove leftover `dbg!` calls.

## Generation

Derive macros (`serde`, `Debug`, `Clone`), `prost` / `tonic-build` in `build.rs` for protobuf and gRPC, `sqlx` compile-time checked queries, `progenitor` or `openapi-generator` for API clients, `bindgen` for C headers.

## Optimization

Always measure release builds (`cargo build --release`). Benchmark with `criterion` (or `divan`), profile with `cargo flamegraph` or `perf`. Check allocations and data layout before reaching for `unsafe`.

## Extensibility

Mark public enums and structs `#[non_exhaustive]` when new variants or fields are likely. Use `#[serde(default)]` and a version field in payloads. Follow semver for crates.
