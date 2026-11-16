from lifecycle import TRANSITIONS, Event, IllegalTransition, State, step
from orders import Order, YearMonth, revenue_by_month, revenue_by_month_spec
from hypothesis import given, strategies as st

year_months = st.builds(YearMonth, st.sampled_from([2024, 2025]), st.integers(1, 12))
orders = st.lists(
    st.builds(Order, id=st.text(max_size=3), total=st.integers(0, 1000),
              paid_in=st.none() | year_months, refunded=st.booleans()),
    max_size=20,
)


@given(orders)
def test_derived_equals_spec(orders):
    assert revenue_by_month(orders, 2024) == revenue_by_month_spec(orders, 2024)


@given(st.lists(st.sampled_from(list(Event)), max_size=8))
def test_lifecycle_invariants(events):
    state = State.DRAFT
    for event in events:
        allowed = (state, event) in TRANSITIONS
        try:
            next_state = step(state, event)
        except IllegalTransition:
            assert not allowed
        else:
            assert allowed
            state = next_state
