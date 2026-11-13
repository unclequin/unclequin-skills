# Testing: The Spec as Oracle

The model and the composed spec tell you what to test. Examples check the cases you thought of. Properties check the laws on inputs you didn't think of. The spec-equals-derived property keeps a fast version honest forever, not just on the day it was written.

## Contents

- What the suite contains
- Generating inputs
- Spec equals derived
- Libraries per language
- When there is no library
- Checking the tests themselves

---

## What the suite contains

1. **Examples from the sentence.** One test per phrase, plus each boundary found in step 1: the first and last instant of the month, an empty list, a refund in a later month, a tie.
2. **Properties from the model.** Two or three set laws or state invariants from `modeling.md`, the ones a likely bug would break.
   For a lifecycle, also check the table against the requirement: list the allowed (state, event) pairs as the requirement states them, reach each state by replaying events, and check that every pair is accepted or rejected as listed. Invariant tests read the code's own table, so they can't catch a wrong entry in it.
3. **Spec equals derived.** Whenever step 4 ran. Random inputs, exact comparison of the whole output, including order and types.

Commit all three. A comparison in a scratch script proves the change once, then disappears. The next person to touch the fast code has nothing to check it against.

## Generating inputs

- **Small values, many cases.** Few customers, small amounts, few months. Collisions, ties, and duplicates show up far more often with a small domain than with a huge one.
- **Include the awkward values.** Zero, negative where allowed, `None`/`nil` fields, the boundaries of a range, repeated keys.
- **Lifecycles: generate events, not states.** Generate a random list of events, replay it from the start state through the public `step`/`replay`, and check the invariants along the way. A state built by hand can be one that no real history reaches, so a test on it may check behavior that can't happen.
- **Shrinking.** Property libraries shrink a failing input to a minimal one. When a test fails, read the shrunk case first, then add it as an example test.
- **Seeds.** Print the seed on failure, and allow a fixed seed in CI if the team needs reproducible runs.

## Spec equals derived

```
property: for all orders, n:
    topCustomers(orders, n) == topCustomersSpec(orders, n)
```

- Compare the whole value: order, types, and values. A sorted comparison hides tie-order bugs.
- Generate inputs that hit the behavior traps in `derivation.md`: tied totals, float amounts, empty input, single-use iterators if the API accepts them.
- If the spec is too slow for big inputs, keep the generated inputs small. The property is about behavior, not scale. Benchmark scale separately.

## Libraries per language

| Language | Library | Notes |
|----------|---------|-------|
| Go | `pgregory.net/rapid` | `testing/quick` in the standard library works for simple generators |
| TypeScript / JavaScript | `fast-check` | works with any test runner, including `node:test` |
| Python | `hypothesis` | the `@given` decorator with pytest or unittest |
| Java / Kotlin | `jqwik` | JUnit 5 engine; Kotest's property testing for Kotlin |
| Rust | `proptest` | `quickcheck` crate is the lighter alternative |
| Haskell | `QuickCheck` | `hedgehog` for integrated shrinking |
| Lean 4 | `plausible` | prefer a proof: state the property as a `theorem` |
| C | `theft` | or a seeded loop in a normal test |

## When there is no library

If adding a dependency isn't possible, a seeded random loop in an ordinary test still finds most bugs:

```
test "spec equals derived":
    rng = Random(seed = 42)
    repeat 1000 times:
        orders = randomOrders(rng, maxLen = 20)
        assert derived(orders) == spec(orders), "seed 42, case " + i
```

It doesn't shrink, so keep generated inputs small, and print the failing input.

## Checking the tests themselves

To make sure a property can fail, break the code on purpose once: flip a boundary comparison, drop a predicate, or let a terminal state accept an event. Run the tests, see a failure, then restore the code. If nothing fails, the property is too weak or the generator never reaches the case.

Make each breakage undoable: in a git repository, break the code and then `git checkout -- <file>` (or `git stash`) to restore it. Otherwise, copy the file to a backup and check the copy exists before editing. Restore after every breakage, so breakages don't pile up.

A property can be blind to a whole class of bugs. "The months together hold all the revenue" still holds when the code reads months in the wrong time zone, because every order still lands in exactly one month. When a breakage passes every property, cover it with an example test instead. Examples guard what the laws can't see.
