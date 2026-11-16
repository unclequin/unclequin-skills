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

Without a dependency, a seeded xorshift generator in a plain `#[test]` loop finds the same bugs, without shrinking.

## Tooling

- Measure before deriving: `cargo bench` with `criterion`, and `cargo flamegraph` or `samply` for profiles. Always benchmark `--release` builds.
- `cargo fmt` and `cargo clippy -- -D warnings` on every change.
