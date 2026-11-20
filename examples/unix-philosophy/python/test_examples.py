import io
from types import SimpleNamespace

import httpx
import pytest

import retry
from config import port_or_exit, port_silent
from count_lines import count_lines
from errors import OrderFetchError, fetch_opaque, fetch_transparent
from fees import shipping_fee
from invoice import User, make_invoice
from quote import PRICES, QuoteV1, QuoteV2, quote_v1, quote_v2
from signup import ValidationError, signup_after


class Recorder:
    def __init__(self):
        self.seen = []

    def create(self, signup):
        self.seen.append(("create", signup["email"]))
        return signup["email"]

    def send_welcome(self, user):
        self.seen.append(("welcome", user))


def test_signup_parses_creates_then_mails():
    recorder = Recorder()
    signup_after(SimpleNamespace(json={"email": "a@b.c"}), recorder, recorder)
    assert recorder.seen == [("create", "a@b.c"), ("welcome", "a@b.c")]
    with pytest.raises(ValidationError):
        signup_after(SimpleNamespace(json={}), recorder, recorder)
    assert len(recorder.seen) == 2


def test_count_lines_takes_any_iterable_of_lines():
    assert count_lines(io.StringIO("a\nb\n")) == 2
    assert count_lines(line for line in ["a", "b", "c"]) == 3


def test_make_invoice_needs_only_get():
    users = SimpleNamespace(get=lambda user_id: User(user_id, "Ada"))
    assert make_invoice(users, "u1").billed_to == "Ada"


def test_with_retry_gives_up_after_max_attempts():
    assert retry.calls == ["call"]  # the module-level call the reference file shows
    attempts = []

    def failing():
        attempts.append(1)
        raise OSError("down")

    with pytest.raises(OSError):
        retry.with_retry(retry.RetryPolicy(max_attempts=3, backoff_seconds=0), failing)
    assert len(attempts) == 3


def test_transparent_error_keeps_context_and_cause():
    assert fetch_opaque("missing") is None
    with pytest.raises(OrderFetchError, match="fetch order missing") as raised:
        fetch_transparent("missing")
    assert isinstance(raised.value.__cause__, httpx.HTTPError)
    assert fetch_transparent("o1") == {"id": "o1"}


def test_bad_port_is_silent_or_fatal(monkeypatch):
    monkeypatch.delenv("PORT", raising=False)
    assert port_silent() == 0
    with pytest.raises(SystemExit, match="invalid PORT: None"):
        port_or_exit()
    monkeypatch.setenv("PORT", "8080")
    assert port_or_exit() == 8080


def test_shipping_fee_reads_the_table():
    assert [shipping_fee(z) for z in ("BKK", "NORTH", "MARS")] == [40, 80, 100]


def test_version_2_answers_every_version_1_request_the_same() -> None:
    for sku in PRICES:
        for quantity in range(1, 101):
            q: QuoteV1 = {"sku": sku, "quantity": quantity}
            assert quote_v2(QuoteV2(**q)) == quote_v1(q)


def test_version_2_new_field_changes_only_the_new_requests():
    assert quote_v2({"sku": "pear", "quantity": 3, "coupon": "TENOFF"}) == 405
    with pytest.raises(KeyError, match="unknown coupon"):
        quote_v2({"sku": "pear", "quantity": 3, "coupon": "BOGUS"})
