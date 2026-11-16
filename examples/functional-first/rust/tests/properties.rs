use orders::*;
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
