# Python Idioms for the Unix Philosophy

"The Zen of Python" (`import this`) overlaps heavily with these rules: simple is better than complex, explicit is better than implicit, errors should never pass silently. Follow PEP 8 and use type hints.

## Modularity: small functions and modules

One module, one responsibility. Prefer plain functions and small dataclasses over large classes. A class that only has `__init__` and one method is usually a function.

```python
# Before: one view, four jobs
def signup_view(request): ...  # parse + validate + insert + email

# After
signup = parse_signup(request.json)   # raises ValidationError
user = user_repo.create(signup)
mailer.send_welcome(user)
```

## Composition: accept iterables and file-like objects

```python
# Hard to compose: only works with a path
def count_lines(path: str) -> int: ...

# Composable: works with open files, io.StringIO, sys.stdin, generators
from collections.abc import Iterable

def count_lines(lines: Iterable[str]) -> int:
    return sum(1 for _ in lines)
```

Generators and `itertools` let you build pipelines of small functions, just like shell pipes.

## Simplicity: duck typing and Protocols

Don't create abstract base classes with one implementation. When you need a contract for type checking, use a narrow `typing.Protocol`.

```python
from typing import Protocol

class UserGetter(Protocol):
    def get(self, user_id: str) -> User: ...

def make_invoice(users: UserGetter, user_id: str) -> Invoice: ...
```

## Separation: policy as parameters or config

```python
from dataclasses import dataclass

@dataclass(frozen=True)
class RetryPolicy:
    max_attempts: int
    backoff_seconds: float

def with_retry(policy: RetryPolicy, fn): ...  # mechanism only

with_retry(RetryPolicy(max_attempts=3, backoff_seconds=0.2), call_partner)
```

## Transparency and Repair: exception chaining, never pass silently

```python
# Opaque and silent
try:
    order = fetch_order(order_id)
except Exception:
    pass

# Transparent: specific exception, context, original cause kept
try:
    order = fetch_order(order_id)
except httpx.HTTPError as e:
    raise OrderFetchError(f"fetch order {order_id}") from e
```

```python
# Silent failure: falls back without telling anyone
port = int(os.environ.get("PORT", "0"))

# Fail fast at startup (or validate all config with pydantic-settings)
try:
    port = int(os.environ["PORT"])
except (KeyError, ValueError) as e:
    raise SystemExit(f"invalid PORT: {os.environ.get('PORT')!r}") from e
```

Red flags: bare `except:`, `except Exception: pass`, returning `None` to signal failure in some places and raising in others, mutable default arguments.

## Representation: dicts and enums

```python
SHIPPING_FEES = {"BKK": 40, "CENTRAL": 60, "NORTH": 80}

def shipping_fee(zone: str) -> int:
    return SHIPPING_FEES.get(zone, 100)
```

`pytest.mark.parametrize` is the same rule applied to tests.

## Least Surprise: Python conventions

- snake_case for functions and variables, PascalCase for classes (PEP 8).
- Use context managers (`with`) for resources.
- Don't mutate arguments unless the name says so; return new values.
- Format with `black` or `ruff format`, lint with `ruff`, type-check with `mypy` or `pyright`.

## Silence

CLIs print results to stdout, write diagnostics to `sys.stderr` or via `logging`, and exit with `sys.exit(1)` on failure. Use `logging` with levels instead of `print` for diagnostics.

## Generation

`datamodel-code-generator` (from OpenAPI or JSON Schema), `openapi-python-client`, `grpcio-tools` for protobuf, `sqlacodegen`.

## Optimization

Measure first: `timeit`, `cProfile` + `snakeviz`, `py-spy`, `pytest-benchmark`. Often the fix is a better data structure (set instead of list for membership) rather than clever code.

## Extensibility

Version payloads (`{"version": 1, "type": ..., "data": ...}`); use keyword-only arguments (`def f(*, timeout=...)`) so new options can be added without breaking callers.
