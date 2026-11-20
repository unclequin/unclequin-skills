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

## Types: sets of values, sets of messages

```python
# Before: three flags and two optional fields allow 2³ combinations of flags,
# each with or without an amount and a tracking number. Four are legal.
@dataclass(frozen=True)
class OrderRecord:
    paid: bool
    shipped: bool
    cancelled: bool
    amount: int | None = None
    tracking: str | None = None
```

```python
# An amount in integer cents, greater than zero. Only parse_amount makes one.
Amount = NewType("Amount", int)


class InvalidAmount(ValueError):
    pass


def parse_amount(raw: str) -> Amount:
    """Parses raw input at the boundary; the core takes only Amount."""
    if not (raw.isascii() and raw.isdigit() and int(raw) > 0):
        raise InvalidAmount(f"invalid amount: {raw!r}")
    return Amount(int(raw))
```

`NewType` exists only for the type checker: at run time an `Amount` is a plain `int`, and nothing stops a caller from writing `Amount(-5)`. What mypy does stop is passing a bare `int` where an `Amount` is expected, so keep `Amount(...)` calls inside `parse_amount` and let review catch the rest. The `isascii` check matters: `isdigit` alone is also true for other scripts' digits and for `"²"`.

```python
# After: one type per state, each holding only its own data.
@dataclass(frozen=True)
class Draft:
    id: str


@dataclass(frozen=True)
class Paid:
    id: str
    amount: Amount


@dataclass(frozen=True)
class Shipped:
    id: str
    amount: Amount
    tracking: str


@dataclass(frozen=True)
class Cancelled:
    id: str


type Order = Draft | Paid | Shipped | Cancelled


def refund_due(order: Order) -> int:
    """The amount to refund on cancellation: only money that was taken."""
    match order:
        case Draft() | Cancelled():
            return 0
        case Paid(amount=amount) | Shipped(amount=amount):
            return amount
        case _:
            assert_never(order)
```

In the last case the type checker has narrowed `order` to `Never`, so adding a fifth state to `Order` makes `assert_never(order)` a type error until every `match` handles it. Python itself doesn't check: without mypy or pyright, the missing case only raises at run time.

```python
def accepts(state: State) -> list[Event]:
    """The messages a state accepts, read from the transition table."""
    return [e for e in Event if (state, e) in TRANSITIONS]


# Typestate: each operation takes only the state that accepts it.
def pay(order: Draft, amount: Amount) -> Paid:
    return Paid(order.id, amount)


def ship(order: Paid, tracking: str) -> Shipped:
    return Shipped(order.id, order.amount, tracking)


def cancel(order: Draft | Paid) -> Cancelled:
    return Cancelled(order.id)
```

`Event` is the set of messages the lifecycle understands, and `accepts` reads one state's subset from `TRANSITIONS` instead of keeping a second list. The signatures turn the same table into a type check for code that drives an order step by step: mypy rejects `ship(draft, ...)`, though Python would run it. Events that arrive as data, from a queue or a database, still go through `step`.

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

```python
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


def test_draft_cant_be_shipped() -> None:
    draft = Draft("o1")
    assert ship(pay(draft, parse_amount("500")), "T1") == Shipped("o1", Amount(500), "T1")

    # mypy fails if this ever type-checks: the file turns on warn-unused-ignores.
    def illegal() -> Shipped:
        return ship(draft, "T1")  # type: ignore[arg-type]
```

With `# mypy: warn-unused-ignores` at the top of the test file, the `type: ignore` is the test: mypy reports it as unused, and fails, if `ship` ever accepts a `Draft`. The test needs a return annotation, since mypy skips the bodies of unannotated functions.

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
