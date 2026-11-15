# Coding standards

Read this when reviewing a change. It holds the judgement calls a reviewer makes; formatting, lint rules, and ignored errors are enforced by the project's checks, so leave those to them. Apply every rule to every unit the change adds or touches, and report each break with its file, line, and the rule it breaks.

## Units

- Each new function, type, module, and service has one job, stated in one sentence without "and".
- Each interface, base class, generic, or plugin point has a second implementation or a test that needs it.

## Business rules

- The top function of a business rule has a doc comment that states the rule in domain words and names the reading chosen for each ambiguous word (time zone, period bounds, rounding, currency).

## Errors and logging

- Every error the change creates or passes on names the operation and the input, and keeps the original cause.
- The success path logs only what an operator would act on.

## Performance

- Each change made for speed cites the benchmark or profile that justified it.
- Code made faster keeps its clear version (the spec, or the old code word for word) in the tests, with a committed test that checks the fast version equals it on random inputs.
