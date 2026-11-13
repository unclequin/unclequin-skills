# Python: Functional First

Generator expressions with `sum`, `any`, and `all` are Python's pipeline, and they read like the sentence. Frozen dataclasses and `NamedTuple` give immutable values, and `Enum` gives a closed set of states. Python doesn't fuse or optimize, so the main derivations are about passes and data structures, not micro-tuning.

## Compose: generator expressions over named predicates

```python
from dataclasses import dataclass
from typing import Iterable, NamedTuple


class YearMonth(NamedTuple):
    year: int
    month: int  # 1-12


@dataclass(frozen=True)
class Order:
    id: str
    total: int  # cents
    paid_in: YearMonth | None
    refunded: bool


def paid_in(month: YearMonth):
    return lambda order: order.paid_in == month


def is_refunded(order: Order) -> bool:
    return order.refunded


def monthly_revenue(orders: Iterable[Order], month: YearMonth) -> int:
    """Revenue for a month is the sum of the totals of orders paid in that
    month, except refunded ones. A refund at any time excludes the order."""
    is_paid = paid_in(month)
    return sum(o.total for o in orders if is_paid(o) and not is_refunded(o))
```

Use `int` cents or `Decimal` for money. `sum` of floats uses compensated summation in Python 3.12+, so a derived `total += x` loop can give a different float than `sum` (see `derivation.md`).

## Derive: group instead of rescanning

```python
def revenue_by_month_spec(orders: list[Order], year: int) -> list[int]:
    """Spec: twelve passes, one per month."""
    return [monthly_revenue(orders, YearMonth(year, m)) for m in range(1, 13)]


def revenue_by_month(orders: Iterable[Order], year: int) -> list[int]:
    """Derived from revenue_by_month_spec by grouping instead of rescanning."""
    out = [0] * 12
    for o in orders:
        if o.paid_in is not None and o.paid_in.year == year and not is_refunded(o):
            out[o.paid_in.month - 1] += o.total
    return out
```

The spec takes a `list` because it reads the input twelve times. The derived version reads it once, so it also accepts a generator. Widening the input type is fine, but the spec-equals-derived test must pass lists.

The common Python performance bug is a nested scan: for each key, loop over all rows again. Grouping with a `dict` (or `collections.defaultdict`, `Counter`) turns O(keys × rows) into O(rows). For millions of rows, measure first, then consider moving the hot loop to a columnar library (polars, pandas, numpy), with the pure-Python spec kept as the oracle.

## State machine: a table as data

```python
from enum import Enum


class State(Enum):
    DRAFT = "draft"
    PAID = "paid"
    SHIPPED = "shipped"
    CANCELLED = "cancelled"


class Event(Enum):
    PAY = "pay"
    SHIP = "ship"
    CANCEL = "cancel"


# The whole lifecycle. A pair that isn't here is illegal.
TRANSITIONS: dict[tuple[State, Event], State] = {
    (State.DRAFT, Event.PAY): State.PAID,
    (State.DRAFT, Event.CANCEL): State.CANCELLED,
    (State.PAID, Event.SHIP): State.SHIPPED,
    (State.PAID, Event.CANCEL): State.CANCELLED,
}


class IllegalTransition(ValueError):
    pass


def step(state: State, event: Event) -> State:
    try:
        return TRANSITIONS[state, event]
    except KeyError:
        raise IllegalTransition(f"cannot {event.value} an order that is {state.value}") from None


def replay(start: State, events: list[Event]) -> State:
    """Folds step over events. Raises at the first illegal one."""
    state = start
    for event in events:
        state = step(state, event)
    return state
```

Raising is the Python idiom for an illegal step. Raise a specific exception type that callers can catch, never a bare `Exception`. When states carry data, make each state a frozen dataclass, keep `TRANSITIONS` keyed by the state's kind, and compute the new data in `step`.

## Check: properties

With Hypothesis:

```python
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
```

Without Hypothesis, use a seeded `random.Random` in a plain `unittest` test. It finds the same bugs but doesn't shrink:

```python
def test_derived_equals_spec(self):
    rng = random.Random(42)
    for case in range(1000):
        orders = random_orders(rng)  # small totals, two years, some unpaid
        self.assertEqual(revenue_by_month(orders, 2024), revenue_by_month_spec(orders, 2024), f"case {case}")
```

## Tooling

- Measure before deriving: `python -m cProfile -s cumtime script.py`, `timeit` for small pieces, or `py-spy` on a running process.
- If the spec's output depends on `set` or `dict` iteration over strings, run the spec-equals-derived test under a few hash seeds: `for s in 0 1 2 3; do PYTHONHASHSEED=$s python -m pytest -q; done`.
- `ruff` for lint and format, `mypy` or `pyright` for types.
