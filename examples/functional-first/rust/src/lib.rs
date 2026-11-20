//! The code shown in skills/functional-first/references/languages/rust.md.
//! scripts/check-examples.py checks that the two stay the same.

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
pub mod types;
