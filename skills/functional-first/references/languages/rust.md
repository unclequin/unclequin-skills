# Rust: Functional First

Iterator chains are the composed form, and they compile to one fused loop with no intermediate collections. So the spec is often already fast, and hand-fusing rarely helps. Enums with exhaustive `match` make the transition table a function the compiler checks, and `try_fold` is replay.

## Compose: an iterator chain of named predicates

```rust
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct YearMonth {
    pub year: i32,
    pub month: u8, // 1-12
}

#[derive(Clone, Debug)]
pub struct Order {
    pub id: String,
    pub total: i64, // cents
    pub paid_in: Option<YearMonth>,
    pub refunded: bool,
}

fn paid_in(month: YearMonth) -> impl Fn(&&Order) -> bool {
    move |o| o.paid_in == Some(month)
}

fn is_refunded(o: &Order) -> bool {
    o.refunded
}

/// Revenue for a month is the sum of the totals of orders paid in that month,
/// except refunded ones. A refund at any time excludes the order.
pub fn monthly_revenue(orders: &[Order], month: YearMonth) -> i64 {
    orders
        .iter()
        .filter(paid_in(month))
        .filter(|o| !is_refunded(o))
        .map(|o| o.total)
        .sum()
}
```

`filter` passes `&&Order` when iterating over `&[Order]`, which is why `paid_in` returns `impl Fn(&&Order) -> bool`. Take `&[Order]` (or `impl IntoIterator<Item = &Order>`) rather than `&Vec<Order>`.

## Derive: group instead of rescanning

```rust
/// Spec: twelve passes, one per month.
pub fn revenue_by_month_spec(orders: &[Order], year: i32) -> [i64; 12] {
    std::array::from_fn(|i| {
        monthly_revenue(
            orders,
            YearMonth {
                year,
                month: i as u8 + 1,
            },
        )
    })
}

/// Derived from `revenue_by_month_spec` by grouping instead of rescanning.
pub fn revenue_by_month(orders: &[Order], year: i32) -> [i64; 12] {
    let mut out = [0; 12];
    for o in orders.iter().filter(|o| !is_refunded(o)) {
        if let Some(m) = o.paid_in.filter(|m| m.year == year) {
            out[usize::from(m.month) - 1] += o.total;
        }
    }
    out
}
```

Rust already fuses the chain, so the derivations that pay off are algorithmic: grouping (`HashMap`, or an array when keys are small integers), early exit (`any`, `find`), and representation changes. Choose overflow behavior on purpose: `+` panics on overflow in debug builds and wraps in release builds. Use `checked_add` in the spec if overflow is possible, so the derived code must match it.

## State machine: an exhaustive match as the table

```rust
use std::fmt;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum State {
    Draft,
    Paid,
    Shipped,
    Cancelled,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Event {
    Pay,
    Ship,
    Cancel,
}

/// The whole lifecycle. A pair that isn't here is illegal.
pub fn transition(state: State, event: Event) -> Option<State> {
    use {Event::*, State::*};
    match (state, event) {
        (Draft, Pay) => Some(Paid),
        (Draft, Cancel) => Some(Cancelled),
        (Paid, Ship) => Some(Shipped),
        (Paid, Cancel) => Some(Cancelled),
        _ => None,
    }
}

#[derive(Debug, PartialEq, Eq)]
pub struct IllegalTransition {
    pub state: State,
    pub event: Event,
}

impl fmt::Display for IllegalTransition {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(
            f,
            "cannot {:?} an order that is {:?}",
            self.event, self.state
        )
    }
}

impl std::error::Error for IllegalTransition {}

pub fn step(state: State, event: Event) -> Result<State, IllegalTransition> {
    transition(state, event).ok_or(IllegalTransition { state, event })
}

/// Folds `step` over events and stops at the first illegal one.
pub fn replay(start: State, events: &[Event]) -> Result<State, IllegalTransition> {
    events
        .iter()
        .try_fold(start, |state, &event| step(state, event))
}
```

The `match` is the table: one line per allowed transition, and `_ => None` for everything else. Keep `transition` free of side effects and data computation so it stays a readable table. When states carry data, give the enum variants fields (`Issued { term: u32 }`), and let the type system make illegal data unrepresentable.

## Types: sets of values, sets of messages

```rust
// Before: three flags and two optional fields allow 2³ combinations of flags,
// each with or without an amount and a tracking number. Four are legal.
pub struct OrderRecord {
    pub paid: bool,
    pub shipped: bool,
    pub cancelled: bool,
    pub amount: Option<u64>,
    pub tracking: Option<String>,
}
```

```rust
/// An amount in integer cents, greater than zero. Only `parse` makes one.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Amount(u64);

impl Amount {
    pub fn cents(self) -> u64 {
        self.0
    }
}

/// Parses raw input at the boundary; the core takes only `Amount`.
impl FromStr for Amount {
    type Err = InvalidAmount;

    fn from_str(raw: &str) -> Result<Self, Self::Err> {
        // u64's own parser also takes a leading '+', so check the digits first.
        let digits = !raw.is_empty() && raw.bytes().all(|b| b.is_ascii_digit());
        match raw.parse::<u64>() {
            Ok(n) if digits && n > 0 => Ok(Amount(n)),
            _ => Err(InvalidAmount(raw.to_string())),
        }
    }
}
```

The field of `Amount` is private, so code outside its module can't write `Amount(0)`: `"500".parse::<Amount>()` is the only way in. Privacy is per module, so keep the newtype in a small module of its own; code in the same module can still build one directly. `InvalidAmount` is an ordinary error type that implements `Display` and `Error`.

```rust
// After: one type per state, each holding only its own data.
pub struct Draft {
    pub id: String,
}

pub struct Paid {
    pub id: String,
    pub amount: Amount,
}

pub struct Shipped {
    pub id: String,
    pub amount: Amount,
    pub tracking: String,
}

pub struct Cancelled {
    pub id: String,
}

pub enum Order {
    Draft(Draft),
    Paid(Paid),
    Shipped(Shipped),
    Cancelled(Cancelled),
}

/// The amount to refund on cancellation: only money that was taken.
pub fn refund_due(order: &Order) -> u64 {
    match order {
        Order::Draft(_) | Order::Cancelled(_) => 0,
        Order::Paid(Paid { amount, .. }) | Order::Shipped(Shipped { amount, .. }) => amount.cents(),
    }
}
```

A `match` must cover every variant, so adding a fifth state is a compile error in every `match` without a `_` arm. Leave `_` out of matches over domain enums for that reason.

```rust
pub const EVENTS: [Event; 3] = [Event::Pay, Event::Ship, Event::Cancel];

/// The messages a state accepts, read from the transition table.
pub fn accepts(state: State) -> Vec<Event> {
    EVENTS
        .into_iter()
        .filter(|&e| transition(state, e).is_some())
        .collect()
}

// Typestate: each state has only the operations it accepts, and each one
// consumes the old state, so it can't be used again.
impl Draft {
    pub fn pay(self, amount: Amount) -> Paid {
        Paid {
            id: self.id,
            amount,
        }
    }

    pub fn cancel(self) -> Cancelled {
        Cancelled { id: self.id }
    }
}

impl Paid {
    pub fn ship(self, tracking: String) -> Shipped {
        Shipped {
            id: self.id,
            amount: self.amount,
            tracking,
        }
    }

    pub fn cancel(self) -> Cancelled {
        Cancelled { id: self.id }
    }
}
```

`Event` is the set of messages the lifecycle understands, and `accepts` reads one state's subset from `transition` instead of keeping a second list. The methods are the same table checked at compile time: `draft.ship(...)` doesn't compile, and because `pay` takes `self` by value, the draft is gone once it is paid. Events that arrive as data, from a queue or a database, still go through `step`.

## Check: properties

With `proptest`:

```rust
use proptest::prelude::*;

fn order() -> impl Strategy<Value = Order> {
    let month = (2024..=2025i32, 1..=12u8).prop_map(|(year, month)| YearMonth { year, month });
    (
        any::<u8>(),
        0..1000i64,
        proptest::option::of(month),
        any::<bool>(),
    )
        .prop_map(|(id, total, paid_in, refunded)| Order {
            id: id.to_string(),
            total,
            paid_in,
            refunded,
        })
}

fn event() -> impl Strategy<Value = Event> {
    prop_oneof![Just(Event::Pay), Just(Event::Ship), Just(Event::Cancel)]
}

proptest! {
    #[test]
    fn derived_equals_spec(orders in proptest::collection::vec(order(), 0..20)) {
        prop_assert_eq!(revenue_by_month(&orders, 2024), revenue_by_month_spec(&orders, 2024));
    }

    #[test]
    fn lifecycle_invariants(events in proptest::collection::vec(event(), 0..8)) {
        let mut state = State::Draft;
        for event in events {
            match step(state, event) {
                Ok(next) => { prop_assert_eq!(transition(state, event), Some(next)); state = next; }
                Err(err) => prop_assert_eq!(err, IllegalTransition { state, event }),
            }
        }
    }
}
```

```rust
#[test]
fn a_state_accepts_exactly_the_events_step_allows() {
    for state in STATES {
        let allowed: Vec<Event> = EVENTS
            .into_iter()
            .filter(|&e| step(state, e).is_ok())
            .collect();
        assert_eq!(accepts(state), allowed);
    }
}

proptest! {
    #[test]
    fn parse_accepts_exactly_the_positive_whole_numbers_of_cents(raw in "[0-9]{0,22}|\\PC{0,8}") {
        let whole = !raw.is_empty() && raw.bytes().all(|b| b.is_ascii_digit());
        let positive = raw.parse::<u64>().is_ok_and(|n| n > 0);
        prop_assert_eq!(raw.parse::<Amount>().is_ok(), whole && positive);
    }

    #[test]
    fn parse_keeps_every_positive_amount(n in 1..=u64::MAX) {
        prop_assert_eq!(n.to_string().parse::<Amount>().map(Amount::cents), Ok(n));
    }
}
```

A doc test marked `compile_fail` turns "this must not compile" into a test, with no extra crate. Put it in the doc comment of the module that holds the typestate:

```rust
//! A draft has no `ship`, so this must not compile:
//!
//! ```compile_fail
//! use orders::types::Draft;
//! let draft = Draft { id: "o1".to_string() };
//! draft.ship("T1".to_string());
//! ```
```

`cargo test` runs it, and fails if the snippet ever compiles. It only checks that compilation fails, not why, so keep the snippet to the one illegal call.

Without a dependency, a seeded xorshift generator in a plain `#[test]` loop finds the same bugs, without shrinking.

## Tooling

- Measure before deriving: `cargo bench` with `criterion`, and `cargo flamegraph` or `samply` for profiles. Always benchmark `--release` builds.
- `cargo fmt` and `cargo clippy -- -D warnings` on every change.
