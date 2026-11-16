"""The state machine shown in
skills/functional-first/references/languages/python.md."""

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
