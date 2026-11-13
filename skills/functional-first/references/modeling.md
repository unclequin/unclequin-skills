# Modeling: Sets and State Machines

Model before you compose when the problem selects things (use sets) or when things move through stages (use a state machine). Both are small, precise, and checkable by a non-programmer, and both hand you property tests for free.

## Contents

- Sets for "which things"
- State machines for "how things change"
- Using both together
- When the model gets big

---

## Sets for "which things"

Most business rules select items from a collection. The words people use map directly to set operations:

| Spoken word | Set operation | In code |
|-------------|---------------|---------|
| "and", "that are also" | intersection A ∩ B | two predicates joined with *and*, or two filters |
| "or", "either" | union A ∪ B | predicates joined with *or* |
| "except", "excluding", "not" | difference A \ B | filter with the negated predicate |
| "all ... are" | for all ∀ | `all` / `every` |
| "any ... is", "at least one" | exists ∃ | `any` / `some` |
| "per customer", "by month" | partition into groups | group-by |
| "the total of", "how many" | aggregate Σ, count | sum, count, fold |

Write the rule as a set expression before writing code:

```
PaidIn(m)  = { o ∈ Orders | paidAt(o) ∈ m }
Refunded   = { o ∈ Orders | refundedAt(o) ≠ none }
Revenue(m) = Σ total(o)  for o ∈ PaidIn(m) \ Refunded
```

When the requirement changes ("also exclude test accounts"), the change is one more set difference, so it is one more predicate in the composition. Each named set becomes one named predicate in step 3.

### Laws that become tests

| Law | Property to test |
|-----|------------------|
| Filtering gives a subset | every item in the result is in the input |
| A predicate splits a set in two | `filter p xs` plus `filter (not p) xs` has the same items as `xs` |
| Sum over a partition | total of the matching items plus total of the rest equals the total of all |
| Filters commute | filtering by `p` then `q` equals filtering by `q` then `p` |
| Filtering is idempotent | filtering twice by `p` equals filtering once |
| Monotonic selection | adding an item that fails `p` doesn't change the result |

Pick the two or three that a bug would most likely break. For the revenue example: "revenue never exceeds the sum of all paid totals", and "adding an unpaid order doesn't change revenue".

## State machines for "how things change"

An order, policy, ticket, or subscription isn't one value. It moves through stages, and only some moves are allowed. List three things:

- **States:** `draft`, `paid`, `shipped`, `cancelled`
- **Events:** `pay`, `ship`, `cancel`
- **Transitions:** the allowed (state, event) → state pairs

```
draft --pay-->    paid
draft --cancel--> cancelled
paid  --ship-->   shipped
paid  --cancel--> cancelled
```

Anything not in the table is rejected with an error that names the state and the event. That covers "ship before pay", "cancel after ship", and every other illegal story, without writing a check for each.

Store the table as data (a map or a match on a closed set of variants), not as scattered `if` statements. One table, read by a pure `step(state, event)`, is the single source of truth for the code and for the tests.

When states carry data (a policy's term number, an order's paid amount), keep the transition table for the *shape* of the lifecycle and let `step` compute the new data. Types can then make illegal data unrepresentable: only `issued` carries a term.

### Questions that find missing transitions

- Which states are terminal? Nothing leaves them.
- Can an event happen twice (pay twice, cancel twice)? Rejected or ignored? Pick one and test it.
- What happens on a timeout or with no event (a quote expires, a premium lapses)? Model it as an event that a scheduler sends.
- Who can send each event? Permission is a separate check outside the table, so keep it outside.

### Invariants that become tests

Generate random event sequences, replay them through `step`, and check:

| Invariant | Example |
|-----------|---------|
| Always exactly one known state | the replayed state is in the state list |
| Terminal states absorb | after `shipped` or `cancelled`, every event is rejected |
| Rejection changes nothing | a rejected event returns the same state and data |
| Every transition matches the table | a step succeeds exactly when the table has its (state, event) pair |
| Monotonic data | a term number never decreases; a paid amount never changes after `paid` |
| Reachability | every state in the table is reachable from the start state |

## Using both together

The states split your data into sets. "All paid orders" is `{ o | state(o) = paid }`. So a typical design is:

1. Model the lifecycle as a state machine.
2. Write reports and rules as set expressions over the states.
3. Compose small functions that follow each set expression and each transition.
4. Turn set laws and state invariants into property tests.

## When the model gets big

For a design with concurrency, retries, or several interacting machines, model checkers built on these same two ideas (TLA+ for state machines, Alloy for sets and relations) can find bugs before code exists. Most features don't need them. Reach for them when a lifecycle has more than one actor changing it at the same time.
