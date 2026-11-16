"""The code shown in skills/functional-first/references/languages/python.md.
scripts/check-examples.py checks that the two stay the same."""

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
