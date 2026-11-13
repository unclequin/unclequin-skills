---
name: functional-first
description: Use when implementing or fixing business rules, filters, reports, totals, calculations, data transformations, workflows, or entity lifecycles (orders, policies, tickets, subscriptions, approvals), when a loop gives wrong results, or when correct code must be made faster without changing its behavior. Works for Go, TypeScript/JavaScript, Python, Java/Kotlin, Rust, Haskell, Lean 4, and C.
---

# Functional First

Write the clearest correct version first, as small pure functions named in the domain's own words. That version is the specification. Make it faster only when a measurement says so, through small steps that each keep the behavior, and keep the specification in the test suite as the oracle for whatever you derive.

The method is inspired by Pieter Hartel and Henk Muller, *Functional C* (1997): specify functionally, then derive efficient imperative code. Everything here is in our own words, extended with modeling and property-based testing.

This skill works inside a feature or function. For splitting a system into modules and interfaces, use the `unix-philosophy` skill.

## The five steps

Run the steps the task needs. The "when" column decides.

| Step | When | What you produce |
|------|------|------------------|
| 1. Say it | Always | One or two sentences in domain words, plus the ambiguous words and the reading you chose |
| 2. Model it | The rule selects things → sets. Things change state over time → state machine. Neither → skip | A set expression or a transition table |
| 3. Compose it | Always | Named pure functions composed so the top function reads like the sentence. This is the spec |
| 4. Derive it | The spec is measured too slow, or the target needs another shape (C, a hot loop) | Faster code, reached by named transformations, with the spec kept |
| 5. Check it | Always | Example tests, property tests from the model, and a spec-equals-derived property if step 4 ran |

A one-condition change takes Say, Compose, Check, and a minute. A new lifecycle or report takes all five.

### 1. Say it

Write the solution in domain words: "Revenue for a month is the sum of the totals of orders paid in that month, except refunded ones." Nouns become types or sets. Qualifiers ("paid in that month", "except refunded") become predicates. Verbs become functions.

Each word that has two readings is a bug waiting to happen. For example: which time zone defines "month"? Does a refund made next month remove the order from this month? List those words. Ask, or pick the more common reading and write it in the top function's doc comment.

### 2. Model it

Read `references/modeling.md`. Two tools:

- **Sets for selection:** "and" is ∩, "or" is ∪, "except" is \, "all" is ∀, "any" is ∃. `Revenue(m) = Σ total(o) for o ∈ PaidIn(m) \ Refunded`.
- **State machines for lifecycles:** a table of states, events, and allowed transitions. Anything not in the table is an error.

The model's laws and invariants become the property tests in step 5.

### 3. Compose it

Read `references/composition.md`. The shape to produce:

- One named predicate or function per phrase of the sentence or set expression: `paidIn(month)`, `isRefunded`, `total`.
- Selection kept apart from aggregation: filter, then sum. Not one loop with every condition inline.
- Lifecycle transitions stored once, as data (a table or map), read by a pure `step(state, event)` function. History is a fold of `step` over events. When a state carries data (a term number), `step` checks the table first, then computes the new data.
- Effects (I/O, clock, database) at the edges. The composed core takes plain values and returns plain values.

Write the sentence from step 1 as the top function's doc comment.

### 4. Derive it

Read `references/derivation.md`. Only after measuring, or when the target language requires it:

1. Keep the spec function. Move it next to the tests, renamed with a `Spec` suffix if needed. When you are speeding up existing code, that code is the spec: copy it word for word, accidental behavior included, before changing anything.
2. Apply one named transformation at a time, such as fusing passes, grouping instead of rescanning, adding an accumulator, or turning recursion into a loop. Run the checks after each one.
3. Watch the behavior traps listed in the derivation file: float summation order, tie order in sorts, integer overflow, one-shot iterators, laziness.
4. Name the transformations in a comment or the commit message.

### 5. Check it

Read `references/testing.md`. The test suite contains:

- **Examples** from the sentence, including each boundary that step 1 surfaced.
- **Properties from the model.** Set laws, such as "the result is a subset of the input" and "paid plus unpaid equals all". State invariants over random event sequences, such as "terminal states accept nothing" and "a rejected event leaves the state unchanged".
- **The table against the requirement**, for a lifecycle. One test lists the allowed (state, event) pairs written straight from the requirement and checks every pair against `step`. The invariant tests read the code's own table, so only this test catches a wrong entry in it.
- **Spec equals derived** on random inputs, whenever step 4 ran. Commit this test. A throwaway comparison script leaves the next change with no oracle.

Use the language's property-testing library. Where none is available, a seeded random loop inside an ordinary test works. In Lean, prove the property instead.

## Language files

Before writing code, read the file for the language in use, in `references/languages/`: `go.md`, `typescript.md` (also JavaScript), `python.md`, `java.md` (also Kotlin), `rust.md`, `haskell.md`, `lean4.md`, `c.md`. Each shows the pipeline idiom, a state machine as data, the error type for a step that can fail, the property-testing library, and what the compiler already derives for you.

For another language, use its standard collection pipeline (or plain loops over named predicates), its sum type or enum for states, and its property-testing library.

## Common mistakes

| Mistake | Fix |
|---------|-----|
| Every condition inline in one loop body | Name each condition. Fusing it into one loop is a derivation step, done only if measured |
| Transitions in a `switch`, and the same rules again as a table in the tests | One transition table, read by `step`. The tests' only other list is the requirement's allowed pairs, used to check the table itself |
| Tests check `step` only against the code's own table | Add the table-against-requirement test. A wrong table entry passes every test that reads the same table |
| The spec-vs-fast comparison lives in a scratch script | Commit it as a property test |
| Optimizing before measuring | Ship the composed version. Derive when a profile or benchmark points at it |
| All five steps on a one-line change | Say, Compose, Check. Model only when there is a set or a lifecycle |
| States built by hand in tests | Reach them by replaying events through the public API, so tests can't create impossible states |
