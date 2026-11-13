# Engineering principles (Unix philosophy, functional first)

This project follows the Unix philosophy in every language it uses, and builds features functional first. Apply both to every design, change, and review. The rules below are complete on their own. If the skills are installed, use them for detail: `unix-philosophy` for system design (modules, interfaces, failures), `functional-first` for the code inside a feature (business rules, reports, lifecycles, making code faster). When a task does both, use both: design the parts with the first, then build each part with the second.

Always express these principles in the idioms of the language you are working in. Don't carry patterns from one language into another.

## Core principles

- **Do one thing well.** Each function, class, module, and service has one job you can state in one sentence without "and".
- **Small interfaces.** Keep contracts narrow (1–3 operations). Accept the most general standard type that works (stream, iterable, reader, function); return specific results.
- **Clear over clever.** Write code a junior engineer can read without explanation. Comments explain why, not what.
- **Simplest thing that works.** No speculative abstractions, one-implementation interfaces, plugin systems, or generics for imagined future needs.
- **Data over logic.** Turn rule-heavy if/switch chains into tables, maps, enums, or config.
- **Separate policy from mechanism.** Business rules and config live apart from transport, storage, UI, and engine code.

## Building a feature (functional first)

- **Say it first.** Write the rule in one or two sentences of domain words, and put it in the top function's doc comment. Where a word has two readings (which time zone is "this month"?), ask or pick one and write it down.
- **Rules that select things are sets.** "And", "or", "except" become named predicates. Keep selecting apart from summing or grouping.
- **Lifecycles are state machines.** One transition table as data, read by a pure `step(state, event)`. Anything not in the table is an error. Replay a history by folding `step` over events.
- **Pure core, effects at the edges.** The clock, database, and network are read outside and passed in as values.
- **The clear version is the spec.** Make it faster only after measuring, one named transformation at a time. Keep the spec (or the old code, word for word) in the tests and check the fast version equals it on random inputs.
- **Test laws, not just examples.** Add property tests for the rule's laws and the lifecycle's invariants, over random inputs and random event sequences. Check the transition table against the requirement's own list of allowed moves.

## Errors and output

- Fail fast and loudly. Never swallow errors: no ignored error values, empty catch blocks, or catch-all handlers that continue silently.
- Add context to every error (what operation, on what input) and keep the original cause.
- Validate config and input at startup and at system boundaries.
- Be silent on success. Log only what an operator would act on. CLIs write results to stdout, errors to stderr, and exit non-zero on failure.

## Between services and languages

- Keep boundaries simple and standard: JSON or protobuf over HTTP/gRPC, versioned payloads, documented schemas.
- Generate clients and types from one source of truth (OpenAPI, protobuf, database schema) instead of hand-writing them in each language.

## Performance

- Make it work, then measure, then optimize. No optimization without a benchmark or profiler evidence from the language's standard tools.

## Before finishing any change, check

1. Can each new unit be described in one sentence?
2. Are all errors handled, with context and the original cause?
3. Is there any abstraction with only one implementation and no test need? Remove it.
4. Is there any noisy logging on the success path? Remove it.
5. Did you optimize anything without measuring? Revert it.
6. Does the code follow the language's own conventions and formatter?
7. Does the top function's doc comment state the rule, and the reading chosen for each ambiguous word?
8. If you made something faster, is the spec-equals-fast test committed?

<!-- Optional: list this repo's languages and tools so Claude uses them, e.g.
## Project stack
- Backend: Go (gofmt, golangci-lint)
- Frontend: TypeScript + React (Prettier, ESLint)
- Data jobs: Python (ruff, mypy)
-->
