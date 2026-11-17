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

The program has two layers. The **core** makes every decision, as pure functions over plain values. The **shell** around it reads input, calls the core once, and carries out the result. Most of the code and nearly all the branches belong in the core.

**Keep the shell thin.** The shell reads, calls, and writes, in a straight line. A branch on domain data in the shell (`if order.total > 1000: notifyFraudTeam()`) is a decision, so move it into the core and let the shell act on what comes back. The branches a shell keeps are about the effects themselves: retry on a timeout, stop when the input ends.

**Return decisions as data.** When the outcome is "do something" (send an email, save a record, call a service), the core returns a description of the action instead of doing it:

```
core:   decide(policies, today) -> [Remind(p1), Lapse(p2), Remind(p7)]   -- pure
shell:  for action in decide(policies, today):
            match action:
                Remind(p) -> mailer.send(reminderFor(p))
                Lapse(p)  -> db.save(lapse(p))
```

The actions are a small closed type, like the tags in "Branches" above. A test calls `decide` and compares the list it returns. No mailer or database is needed, and "what should happen" is checked separately from "did it happen". The `match` in the shell is the one place that turns an action into an effect, and it stays a plain lookup.

**A read in the middle: split into stages.** When the logic needs data it can only know to fetch partway through, cut it at the read. Each stage is pure, and the shell does the read between them:

```
core:   ids = needsProviderStatus(refunds)              -- which ones are unclear?
shell:  statuses = provider.fetchStatus(ids)
core:   plan = settle(refunds, statuses)                -- decide with the answers
shell:  execute(plan)
```

Pass the fetched values into the core, not the database handle or a fetching callback. A core that holds a fetcher still does its own effects, just one call away, and its tests need a fake fetcher again. When the stages repeat until done (page through results, follow links), the shell loops and the core decides each round: "fetch these next", or "finished, here is the result".

**Failures split the same way.** A domain failure (an illegal transition, an invalid quantity) is a value the core returns, as in "Failures" above. An effect failure (the network is down, the file is missing) happens in the shell, which reports it with the operation and input that failed. The core never sees a timeout, so its result type stays about the domain.

**Test each layer for what it does.** The core gets the unit and property tests: many of them, fast, over generated inputs. The shell gets a few integration tests that check the wiring with real or fake I/O: the right reads happen, each action reaches the right effect, and an effect failure is reported. If the shell needs many tests, it is making decisions, and those belong in the core.

**Large inputs stream through the core.** When the data is too big to read at once, the shell reads it in chunks and folds a pure function over them, `fold step over chunks`, the same shape as replaying events. The core still sees only values; streaming is the shell's job.

## Naming

- Use the domain's words: `paidIn`, `isRefunded`, `lapse`, `renew`. Avoid `process`, `handle`, `check1`, or `helper`.
- Name predicates as questions (`isRefunded`, `paidIn(month)`) and transformations as nouns or results (`total`, `netAmount`).
- Write the step 1 sentence as the top function's doc comment, along with the ambiguities you resolved. For example: "the month is defined in `loc`; a refund at any time excludes the order".
