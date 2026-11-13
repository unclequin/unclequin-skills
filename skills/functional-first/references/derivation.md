# Derivation: From Spec to Fast Code

Derivation turns the composed spec into efficient code through small steps. Each step keeps the behavior the same, so the result is correct by construction, and the spec-equals-derived property test confirms it.

This is the core idea of Hartel and Muller's *Functional C*: write a clear functional version, then derive the imperative version, bringing in assignment, loops, and in-place updates deliberately and only where needed. The transformation style goes back to Burstall and Darlington's fold/unfold rules (1977) and the Bird–Meertens calculus. The catalog below is our own selection for everyday code.

## Contents

- When to derive
- The procedure
- Transformation catalog
- Behavior traps
- What compilers already do

---

## When to derive

Derive when one of these is true:

- A benchmark or profiler shows that the composed code is the bottleneck, at realistic input sizes.
- The target can't express the spec directly. In C, for example, there are no closures or garbage-collected lists, so the spec lives in tests or comments and the code is derived.
- The spec's complexity is wrong for the input, such as a nested scan (O(n·m)) over millions of rows.

Otherwise, ship the composed version. It's the easiest to change.

## The procedure

1. Keep the spec. Move it next to the tests (as `monthlyRevenueSpec`, or `topCustomersSpec`) or keep it as the reference implementation in a test helper. When you are optimizing code that already exists, the existing code is the spec. Copy it word for word, including behavior that looks accidental (tie order, a zero total for a customer with nothing paid). Callers may depend on it. Change that behavior only as a separate, deliberate decision.
2. Write the spec-equals-derived property test before transforming. It passes trivially at first.
3. Apply one transformation from the catalog. Run the tests.
4. Repeat until the measurement is good enough. Then stop.
5. Name the transformations you applied, in a comment above the derived function or in the commit message ("grouped instead of rescanning; fused filter and sum").

## Transformation catalog

Examples are in neutral pseudo-code. The language files show the idioms.

### Fuse passes

**When:** several passes over the same data (filter, then map, then sum) and the intermediate lists cost memory or time.

```
before: sum(map(total, filter(p, xs)))
after:  acc = 0; for x in xs: if p(x): acc += total(x)
```

**Keeps behavior if:** the functions are pure and the order of combining doesn't matter (see the float trap).

### Group instead of rescanning

**When:** for each key, the code scans the whole collection again. That's O(keys × items).

```
before: [(k, sum(total(x) for x in xs if key(x) == k)) for k in keys(xs)]
after:  groups = {}; for x in xs: groups[key(x)].append(x)    -- one pass
        [(k, sum(total(x) for x in groups.get(k, []))) for k in keys(xs)]
```

**Keeps behavior if:** the output order of keys is kept (iterate the same key list as before), and keys with no matches still appear when the spec includes them.

### Introduce an accumulator

**When:** a recursive function does work after the recursive call returns (`sum(x:xs) = x + sum(xs)`), so stack depth grows with input size.

```
before: sum([])   = 0
        sum(x:xs) = x + sum(xs)
after:  sumAcc(acc, [])   = acc
        sumAcc(acc, x:xs) = sumAcc(acc + x, xs)
        sum(xs) = sumAcc(0, xs)
```

**Keeps behavior if:** the combining operation is associative and has an identity (`+` with `0`). For floats, this changes the summation order.

### Turn tail recursion into a loop

**When:** the language doesn't guarantee tail-call elimination (C, Go, Java, Python, JavaScript in practice).

```
before: sumAcc(acc, x:xs) = sumAcc(acc + x, xs)
after:  acc = 0; while xs not empty: acc = acc + head(xs); xs = tail(xs)
```

The parameters become loop variables. The base case becomes the loop condition. Mechanical and always safe.

### Hoist invariant work

**When:** something computed inside a loop doesn't depend on the loop variable (month boundaries, a compiled regex, a lookup table).

```
before: for o in orders: if inRange(o.paidAt, startOf(m), startOf(next(m))): ...
after:  start, end = startOf(m), startOf(next(m)); for o in orders: if start <= o.paidAt < end: ...
```

### Change the representation

**When:** the operation the hot path needs is slow on the current data structure.

| Spec uses | Derived uses | Gains |
|-----------|--------------|-------|
| list membership | hash set | O(1) lookup |
| list of (key, value) | hash map | O(1) lookup by key |
| repeated "is in range" over sorted data | sorted array + binary search | O(log n) |
| small fixed set of flags | bit set | memory, speed |
| immutable list rebuilt each step | array updated in place | allocation (only when the old value is no longer used) |

Wrap the new representation behind the same functions (`contains`, `lookup`) so the composed code above it doesn't change.

### Exit early

**When:** the spec computes a whole collection but only needs part of it.

```
before: length(filter(p, xs)) > 0
after:  any(p, xs)                      -- stops at the first match
before: take(n, sortBy(key, xs))
after:  n smallest by key using a heap  -- O(items · log n) instead of a full sort
```

**Keeps behavior if:** ties are broken the same way (see the tie-order trap).

### Tabulate (memoize)

**When:** a pure function is called again and again with the same arguments (recursive counts, prices per product).

```
before: fib(n) = fib(n-1) + fib(n-2)
after:  table[0..n] filled from the bottom up
```

**Keeps behavior if:** the function is pure. That is exactly what the composed spec guarantees.

### Update in place

**When:** profiling shows allocation for new copies, and the old value is never used again.

Replace "return a new array with element i changed" by "set element i" only where no one else holds the old value. In Rust, ownership enforces this. In C, Go, and Java, check it by reading the callers, then write the reason in a comment.

## Behavior traps

These are the places where a "pure refactor" changes results. Check each one that applies, and cover it in the spec-equals-derived test:

| Trap | Why it changes results | Guard |
|------|------------------------|-------|
| Float summation order | `(a + b) + c ≠ a + (b + c)` for floats. Some `sum` functions also use compensated summation (Python 3.12+), so `acc += x` differs from `sum` | Use integers or decimals for money. Otherwise keep the same combining function and order |
| Tie order | sorting by key keeps equal items in input order only if the sort is stable, and only if the input order is the same | Keep the same input order and a stable sort, or define an explicit tie-breaker in the spec |
| Integer overflow | grouping or reordering can overflow in an intermediate value where the spec didn't | Use a wider type, or checked arithmetic in the spec |
| One-shot iterators | the spec may traverse its input twice; a generator or stream can only be read once | Decide in the spec whether input is a collection or a stream |
| Laziness and strictness | a lazy spec may never evaluate an element that a strict loop does (and throws on) | Make error behavior part of the spec, and test it |
| Hash iteration order | map and set iteration order may differ between runs or languages | In a new spec, don't depend on it: sort explicitly where order matters. If an existing spec already depends on it (a set of keys that decides tie order), build the same set from the same inserts in the same sequence in the derived code, and run the tests under several hash seeds |
| Empty input | `max`, `min`, or `average` of nothing | State the empty result in the spec |

## What compilers already do

Before deriving by hand, check what the toolchain already does. The language files have details.

- **Rust:** iterator chains fuse into one loop with no intermediate collections. Hand-fusing rarely helps.
- **Haskell:** list fusion often removes intermediate lists. Use strict folds (`foldl'`) for accumulators.
- **Java:** streams are lazy and fuse into one pass, with per-element overhead. Use a loop only if measured.
- **Go, Python, C:** no automatic fusion. Each pass is a pass. Measure, then fuse by hand.
- **Lean:** `List` functions are clear but allocate. `Array` with `for` loops (in `Id.run do`) compiles to in-place updates when the array isn't shared.
