# Engineering principles (Unix philosophy)

This project follows the Unix philosophy in every language it uses. Apply it to every design, change, and review. For detailed rules and idiomatic examples per language, use the `unix-philosophy` skill.

Always express these principles in the idioms of the language you are working in. Don't carry patterns from one language into another.

## Core principles

- **Do one thing well.** Each function, class, module, and service has one job you can state in one sentence without "and".
- **Small interfaces.** Keep contracts narrow (1–3 operations). Accept the most general standard type that works (stream, iterable, reader, function); return specific results.
- **Clear over clever.** Write code a junior engineer can read without explanation. Comments explain why, not what.
- **Simplest thing that works.** No speculative abstractions, one-implementation interfaces, plugin systems, or generics for imagined future needs.
- **Data over logic.** Turn rule-heavy if/switch chains into tables, maps, enums, or config.
- **Separate policy from mechanism.** Business rules and config live apart from transport, storage, UI, and engine code.

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

<!-- Optional: list this repo's languages and tools so Claude uses them, e.g.
## Project stack
- Backend: Go (gofmt, golangci-lint)
- Frontend: TypeScript + React (Prettier, ESLint)
- Data jobs: Python (ruff, mypy)
-->
