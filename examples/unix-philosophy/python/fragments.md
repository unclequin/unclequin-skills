# Fragments: python

Code that `skills/unix-philosophy/references/languages/python.md` shows on purpose
in a form that can't be compiled, with the reason. `scripts/check-examples.py`
skips exactly these paragraphs; everything else the file shows is in the
tested sources in this folder.

The "before" signature has `...` for a body, which mypy rejects for a function that returns `int`; the next paragraphs redefine `count_lines`.

```python
# Hard to compose: only works with a path
def count_lines(path: str) -> int: ...
```

`make_invoice` is shown with `...` for a body, which mypy rejects for a function that returns `Invoice`. `invoice.py` has it with a real body.

```python
def make_invoice(users: UserGetter, user_id: str) -> Invoice: ...
```

`with_retry` is shown with `...` for a body, so it would retry nothing. `retry.py` has it with a real body.

```python
def with_retry(policy: RetryPolicy, fn): ...  # mechanism only
```
