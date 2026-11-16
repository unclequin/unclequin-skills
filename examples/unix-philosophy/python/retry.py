import time
from dataclasses import dataclass


@dataclass(frozen=True)
class RetryPolicy:
    max_attempts: int
    backoff_seconds: float


def with_retry(policy: RetryPolicy, fn):
    for attempt in range(1, policy.max_attempts + 1):
        try:
            return fn()
        except Exception:
            if attempt == policy.max_attempts:
                raise
            time.sleep(policy.backoff_seconds)


calls: list[str] = []


def call_partner():
    calls.append("call")
    return "ok"


with_retry(RetryPolicy(max_attempts=3, backoff_seconds=0.2), call_partner)
