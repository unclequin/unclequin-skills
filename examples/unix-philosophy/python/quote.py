from typing import NotRequired, TypedDict


class QuoteV1(TypedDict):
    """Version 1 of the quote request."""

    sku: str
    quantity: int


class QuoteV2(QuoteV1):
    """Version 2 adds an optional coupon, so every version 1 request is still valid."""

    coupon: NotRequired[str]


PRICES = {"apple": 100, "pear": 150}
PERCENT_OFF = {"TENOFF": 10}


def lookup(table: dict[str, int], key: str, what: str) -> int:
    if key not in table:
        raise KeyError(f"unknown {what}: {key}")
    return table[key]


def quote_v1(q: QuoteV1) -> int:
    return lookup(PRICES, q["sku"], "sku") * q["quantity"]


def quote_v2(q: QuoteV2) -> int:
    total = lookup(PRICES, q["sku"], "sku") * q["quantity"]
    if "coupon" not in q:
        return total
    return total - total * lookup(PERCENT_OFF, q["coupon"], "coupon") // 100
