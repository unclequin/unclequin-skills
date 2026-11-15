# Engineering principles (Unix philosophy, functional first)

This project follows the Unix philosophy in every language it uses, and builds features functional first. The rules below are complete on their own. When the skills are installed, use them for detail: `unix-philosophy` for system design (modules, interfaces, failures), `functional-first` for the code inside a feature (business rules, reports, lifecycles, making code faster). When a task does both, design the parts with the first, then build each part with the second.

Express every rule in the idioms of the language at hand, the way its own standard library would.

## Core principles

- **Do one thing well.** Each function, class, module, and service has one job you can state in one sentence without "and".
- **Small interfaces.** Keep contracts narrow (1–3 operations). Accept the most general standard type that works (stream, iterable, reader, function); return specific results.
- **Comments explain why.** The code says what it does; a comment records the reason, the constraint, or the trap.
- **Simplest thing that works.** Add an interface, base class, generic, or plugin point when a second implementation or a test needs it.
- **Data over logic.** Turn rule-heavy if/switch chains into tables, maps, enums, or config.
- **Separate policy from mechanism.** Business rules and config live apart from transport, storage, UI, and engine code.

## Building a feature (functional first)

- **Say it first.** Write the rule in one or two sentences of domain words, and put it in the top function's doc comment. Where a word has two readings (which time zone is "this month"?), ask or pick one and write it down.
- **Rules that select things are sets.** "And", "or", "except" become named predicates. Keep selecting apart from summing or grouping.
- **Lifecycles are state machines.** One transition table as data, read by a pure `step(state, event)`. Anything not in the table is an error. Replay a history by folding `step` over events.
- **Pure core, effects at the edges.** The clock, database, and network are read outside and passed in as values.
- **The clear version is the spec.** Make code faster only with benchmark or profiler evidence, one named transformation at a time. Keep the spec (or the old code, word for word) in the tests and check the fast version equals it on random inputs.
- **Test laws, not just examples.** Add property tests for the rule's laws and the lifecycle's invariants, over random inputs and random event sequences. Check the transition table against the requirement's own list of allowed moves.

## Errors and output

- Fail fast and loudly: every error is returned, wrapped, or stops the program. Never ignore an error value or catch one and carry on silently.
- Add context to every error (what operation, on what input) and keep the original cause.
- Validate config and input at startup and at system boundaries.
- Be silent on success. Log only what an operator would act on. CLIs write results to stdout, errors to stderr, and exit non-zero on failure.

## Between services

- Version payloads that cross a service boundary, and generate clients and types from one source of truth (OpenAPI, protobuf, database schema).

## Review

When reviewing a change, apply the project's `CODING_STANDARDS.md` if it has one, and report every place the change breaks a rule.

<!-- Optional: list this repo's languages and tools so Claude uses them, e.g.
## Project stack
- Backend: Go (gofmt, golangci-lint)
- Frontend: TypeScript + React (Prettier, ESLint)
- Data jobs: Python (ruff, mypy)
-->
