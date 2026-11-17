# Functional first

A method for going from a real-world rule to correct code: write the clearest correct version first, and keep it as the specification for anything faster.

## What it does

The skill walks Claude through five steps:

1. **Say it.** State the rule in one or two sentences of domain words, and settle each ambiguous word.
2. **Model it.** Rules that select things become sets of named predicates; lifecycles become a state machine with one transition table.
3. **Compose it.** Small pure functions named in the domain's words, with effects (clock, database, network) kept in a thin outer shell.
4. **Derive it.** Make it faster only when a measurement says so, one named transformation at a time.
5. **Check it.** Property tests for the rule's laws, with the clear version as the oracle for the fast one.

It has examples for Go, TypeScript/JavaScript, Python, Java/Kotlin, Rust, Haskell, Lean 4, and C. It works inside a feature or function; for splitting a system into modules and interfaces, install the companion plugin `unix-philosophy`.

## When Claude uses it

Claude loads the skill on its own when you are:

- implementing or fixing business rules, filters, reports, totals, or calculations
- building workflows or entity lifecycles (orders, policies, tickets, subscriptions, approvals)
- chasing a loop that gives wrong results
- making correct code faster without changing what it does

To call it by name, run `/functional-first:functional-first`.

## More

Source, the always-on rules template, and install options: https://github.com/unclequin/unclequin-skills
