"""The types section of skills/functional-first/references/languages/python.md.
Not named types.py, which would shadow the standard library module."""

from dataclasses import dataclass
from typing import NewType, assert_never

from lifecycle import TRANSITIONS, Event, State


# Before: three flags and two optional fields allow 2³ combinations of flags,
# each with or without an amount and a tracking number. Four are legal.
@dataclass(frozen=True)
class OrderRecord:
    paid: bool
    shipped: bool
    cancelled: bool
    amount: int | None = None
    tracking: str | None = None


# An amount in integer cents, greater than zero. Only parse_amount makes one.
Amount = NewType("Amount", int)


class InvalidAmount(ValueError):
    pass


def parse_amount(raw: str) -> Amount:
    """Parses raw input at the boundary; the core takes only Amount."""
    if not (raw.isascii() and raw.isdigit() and int(raw) > 0):
        raise InvalidAmount(f"invalid amount: {raw!r}")
    return Amount(int(raw))


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


def accepts(state: State) -> list[Event]:
    """The messages a state accepts, read from the transition table."""
    return [e for e in Event if (state, e) in TRANSITIONS]


# Typestate: each operation takes only the state that accepts it.
def pay(order: Draft, amount: Amount) -> Paid:
    return Paid(order.id, amount)


def ship(order: Paid, tracking: str) -> Shipped:
    return Shipped(order.id, order.amount, tracking)


def cancel(order: Draft | Paid) -> Cancelled:
    """Draft | Paid is the set of states that accept cancel.
    Law: cancelling keeps the order's id."""
    return Cancelled(order.id)
