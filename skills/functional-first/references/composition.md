# Composition: From Sentence to Code

The composed version is the specification. It should read like the sentence from step 1, so a reviewer can check the code against the requirement phrase by phrase.

## Contents

- One phrase, one function
- Straight-line pipelines
- When the problem isn't a straight line: branches, failures, state, effects
- Naming

---

## One phrase, one function

Take the sentence and the set expression and give each phrase a name:

| Phrase | Function |
|--------|----------|
| "orders paid in that month" | `paidIn(month): Order -> bool` |
| "except refunded ones" | `isRefunded: Order -> bool` |
| "the totals" | `total: Order -> Money` |
| "the sum of" | `sum` |

Then compose them:

```
monthlyRevenue(orders, month) =
    sum(map(total, filter(o -> paidIn(month)(o) and not isRefunded(o), orders)))
```

Each named function is small enough to test on its own, and each change to the rule lands in one place. "Exclude test accounts" is one new predicate and one more `and not`.

Keep selection (filter) apart from aggregation (sum, count, group). A loop that checks five conditions and adds to a total in the same body is a fused, derived form. It's fine as the output of step 4, after measuring. As the first version, it hides the rule.

In languages where pipelines aren't idiomatic (Go, C), a plain loop that calls named predicates is the composed form:

```
for each o in orders:
    if paidIn(month, o) and not isRefunded(o):
        sum += total(o)
```

The condition still reads like the sentence. What matters is the names, not the `filter` keyword.

## Straight-line pipelines

| Need | Shape |
|------|-------|
| Select | `filter(pred)` |
| Transform each | `map(f)` |
| Combine into one value | `fold` / `reduce` / `sum` / `count` |
| Group | `groupBy(key)`, then aggregate each group |
| Top N | sort by key, take N (derive to a heap only if measured) |
| Check all or any | `all(pred)` / `any(pred)`, which short-circuit |
| Join two collections | build a map from one by key, then look up from the other |

## When the problem isn't a straight line

### Branches: classify, then handle

When different items follow different rules, write a decision function that returns a tag. Then handle each tag with its own small function.

```
classify(order) -> Domestic | International | Exempt
shippingFee(order) = match classify(order):
    Domestic      -> domesticFee(order)
    International -> internationalFee(order)
    Exempt        -> 0
```

The decision is now one testable function, and the language's exhaustiveness check (in Rust, Haskell, Lean, TypeScript, Java and Kotlin) catches a missing case. When the rules are a lookup ("fee by region"), the decision is a table, not code.

### Failures: a result type, and fail at the first error

When a step can fail (parse, validate, an illegal transition), return the language's result type: `error` in Go, `Result` in Rust, `Either` in Haskell, a tagged union in TypeScript, `Except` in Lean, or an exception in Python and Java where that is the idiom. Compose so the first failure stops the pipeline and carries context:

```
placeOrder(input) =
    parse(input)          -- may fail: "line 3: quantity is not a number"
    then validate         -- may fail: "quantity must be positive"
    then price            -- pure
```

Validate at the boundary. Inside the core, functions take already-valid values, so they don't re-check.

### State: a pure step, folded over events

A lifecycle is a pure function `step(state, event) -> Result<state>` that reads the transition table. A whole history is a fold:

```
replay(start, events) = fold step over events, stopping at the first error
```

The real-world story "created, paid, then shipped" is literally the input `[pay, ship]`. An illegal story fails at the exact event where it goes wrong. Tests generate event lists, which is easier and safer than building states by hand.

Keep the table in one place in the code. The tests use it in two different ways, for two different jobs:

- **Invariant tests import the code's table.** "A step succeeds exactly when the table has the pair" and "a rejected event changes nothing" check that `step` and `replay` follow the table.
- **One test checks the table itself** against the allowed pairs written straight from the requirement, as a short list in the test. A wrong entry in the code's table passes every test that reads that same table. Only this one catches it.

When a state carries data, `step` asks the table whether the move is legal, then computes the new data in a small function (`enter(state, event, next)`): issuing starts term 1, renewing adds one. The table stays a readable list of moves, and the data rules stay next to it.

### Effects: a functional core, an imperative shell

Reading the clock, the database, or the network is not part of the rule. Pass those values in:

```
shell:  orders = db.loadOrders(); month = clock.currentMonth()
core:   revenue = monthlyRevenue(orders, month)       -- pure
shell:  report.write(revenue)
```

`monthlyRevenue(orders, month)` with `month` as a parameter is testable and reusable. `monthlyRevenue()` that reads `time.Now()` inside is neither.

## Naming

- Use the domain's words: `paidIn`, `isRefunded`, `lapse`, `renew`. Avoid `process`, `handle`, `check1`, or `helper`.
- Name predicates as questions (`isRefunded`, `paidIn(month)`) and transformations as nouns or results (`total`, `netAmount`).
- Write the step 1 sentence as the top function's doc comment, along with the ambiguities you resolved. For example: "the month is defined in `loc`; a refund at any time excludes the order".
