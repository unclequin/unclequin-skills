//! Types: sets of values, sets of messages. The code shown in the "Types"
//! section of skills/functional-first/references/languages/rust.md.
//!
//! A draft has no `ship`, so this must not compile:
//!
//! ```compile_fail
//! use orders::types::Draft;
//! let draft = Draft { id: "o1".to_string() };
//! draft.ship("T1".to_string());
//! ```

use crate::{transition, Event, State};
use std::fmt;
use std::str::FromStr;

// Before: three flags and two optional fields allow 2³ combinations of flags,
// each with or without an amount and a tracking number. Four are legal.
pub struct OrderRecord {
    pub paid: bool,
    pub shipped: bool,
    pub cancelled: bool,
    pub amount: Option<u64>,
    pub tracking: Option<String>,
}

/// An amount in integer cents, greater than zero. Only `parse` makes one.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Amount(u64);

impl Amount {
    pub fn cents(self) -> u64 {
        self.0
    }
}

#[derive(Debug, PartialEq, Eq)]
pub struct InvalidAmount(pub String);

impl fmt::Display for InvalidAmount {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "invalid amount: {:?}", self.0)
    }
}

impl std::error::Error for InvalidAmount {}

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

pub const STATES: [State; 4] = [State::Draft, State::Paid, State::Shipped, State::Cancelled];

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
