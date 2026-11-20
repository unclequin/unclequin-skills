use orders::types::{accepts, refund_due, Amount, Cancel, Draft, Order, Paid, EVENTS, STATES};
use orders::{step, Event};
use proptest::prelude::*;

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

#[test]
fn a_paid_draft_can_be_shipped() {
    let amount: Amount = "500".parse().unwrap();
    let draft = Draft {
        id: "o1".to_string(),
    };
    let shipped = draft.pay(amount).ship("T1".to_string());
    assert_eq!(refund_due(&Order::Shipped(shipped)), 500);
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

    /// The law of `Cancel`, run against every type in the set.
    #[test]
    fn cancel_keeps_the_id(id in "\\PC{0,12}", amount in 1..=u64::MAX) {
        let amount: Amount = amount.to_string().parse().unwrap();
        let draft = Draft { id: id.clone() };
        let paid = Paid { id: id.clone(), amount };
        prop_assert!(keeps_id(draft, &id));
        prop_assert!(keeps_id(paid, &id));
    }
}

fn keeps_id<T: Cancel>(order: T, id: &str) -> bool {
    order.cancel().id == id
}
