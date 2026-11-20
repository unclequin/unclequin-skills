# mypy: warn-unused-ignores
import re

from hypothesis import given, strategies as st

from lifecycle import Event, IllegalTransition, State, step
from order_types import (Amount, Draft, InvalidAmount, Shipped, accepts,
                         cancel, parse_amount, pay, refund_due, ship)


def allowed(state: State, event: Event) -> bool:
    try:
        step(state, event)
    except IllegalTransition:
        return False
    return True


def test_accepts_exactly_what_step_allows():
    for state in State:
        assert accepts(state) == [e for e in Event if allowed(state, e)]


@given(st.text() | st.integers().map(str))
def test_parse_amount_accepts_exactly_positive_whole_cents(raw):
    valid = re.fullmatch(r"[0-9]+", raw) is not None and int(raw) > 0
    try:
        parse_amount(raw)
    except InvalidAmount:
        assert not valid
    else:
        assert valid


@given(st.integers(min_value=1))
def test_parse_amount_round_trips(n):
    assert parse_amount(str(n)) == n


def test_draft_cant_be_shipped() -> None:
    draft = Draft("o1")
    assert ship(pay(draft, parse_amount("500")), "T1") == Shipped("o1", Amount(500), "T1")

    # mypy fails if this ever type-checks: the file turns on warn-unused-ignores.
    def illegal() -> Shipped:
        return ship(draft, "T1")  # type: ignore[arg-type]


@given(st.text(), st.integers(min_value=1))
def test_cancel_keeps_the_id(order_id: str, cents: int) -> None:
    draft = Draft(order_id)
    assert cancel(draft).id == order_id
    assert cancel(pay(draft, Amount(cents))).id == order_id


def test_refund_due_is_the_money_taken() -> None:
    paid = pay(Draft("o1"), parse_amount("500"))
    assert [refund_due(o) for o in (Draft("o1"), paid, ship(paid, "T1"), cancel(paid))] == [0, 500, 500, 0]
