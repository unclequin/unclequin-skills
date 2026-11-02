# The 17 Rules: Language-Neutral Explanations

Source: Eric S. Raymond, *The Art of Unix Programming* (2003), Chapter 1, "Basics of the Unix Philosophy". Explanations are paraphrased for modern software development. For idiomatic code examples, see `languages/<language>.md`.

## Contents

1. Modularity · 2. Clarity · 3. Composition · 4. Separation · 5. Simplicity · 6. Parsimony · 7. Transparency · 8. Robustness · 9. Representation · 10. Least Surprise · 11. Silence · 12. Repair · 13. Economy · 14. Generation · 15. Optimization · 16. Diversity · 17. Extensibility · Rob Pike's rules · McIlroy's summary

---

## 1. Modularity: simple parts, clean interfaces

Complexity is managed by breaking a system into parts small enough to understand on their own. Each part can then be fixed, tested, or replaced without touching the rest.

**Red flags:** a "god" class or module with many dependencies; one function that parses, validates, saves, and sends notifications; a service that owns unrelated data.

**Fix:** split by responsibility. Each unit should have one reason to change.

## 2. Clarity: clear beats clever

Code is read far more often than it is written. Code that is hard to read is expensive to maintain and easy to break.

**Red flags:** dense one-liners, bit tricks without need, nested ternaries, single-letter names outside tiny scopes, magic numbers.

**Fix:** use named intermediate variables, early returns, and named constants.

## 3. Composition: design parts to connect

Programs and modules are more valuable when their outputs can feed other programs. Standard interfaces and formats make that possible.

**Red flags:** a function that takes a file path when it could take a stream or iterable; output in a private format; a CLI that can't read stdin or write to stdout.

**Fix:** accept the language's most general standard abstraction (stream, reader, iterable, sequence, function). Emit standard formats (plain text, JSON, CSV, line-delimited records).

## 4. Separation: policy apart from mechanism

Policy (what should happen: business rules, thresholds, config) changes often. Mechanism (how it happens: the engine, transport, storage) changes rarely. Mixing them means every policy change risks breaking the engine.

**Red flags:** retry counts, prices, or feature rules hardcoded inside HTTP, database, or UI code.

**Fix:** the mechanism takes the policy as a parameter or reads it from config.

## 5. Simplicity: add complexity only when forced

Every abstraction has a cost. Add one when a real, present need demands it.

**Red flags:** an interface with exactly one implementation and no testing need; factory-of-factories; deep inheritance trees; generics or plugins "just in case".

**Fix:** start concrete. Extract an abstraction when a second real use appears or a test double is actually needed. The wider an interface, the weaker the abstraction.

## 6. Parsimony: big programs only when nothing else works

Large programs are hard to maintain and hard to delete. Prefer a function over a module, a module over a service, a service over a platform.

**Red flags:** a new microservice for logic with one caller; a framework adopted to solve a 50-line problem.

## 7. Transparency: make it easy to see inside

Debugging takes most of a program's lifetime. Design so you can see what a component is doing and why.

**Red flags:** errors without context; re-throwing generic errors that drop the original cause; no health checks or metrics; opaque global state.

**Fix:** add context to every error (what operation, on what input) while preserving the original cause. Use structured logs. Give important types a readable string form.

## 8. Robustness: comes from simplicity and transparency

Robust software handles unexpected input without falling over. That is far easier when the code is simple enough to reason about and visible enough to debug.

**Red flags:** layers of defensive code compensating for logic nobody understands.

## 9. Representation: put knowledge in data

Data is easier to read, change, and verify than branching logic.

**Red flags:** long switch or if/else chains that map inputs to outputs; rules duplicated across functions.

**Fix:** use lookup tables, maps, enums with attached data, or config files.

## 10. Least Surprise: do the expected thing

Callers and users bring expectations. Meet them by following the conventions of the language, framework, and platform.

**Red flags:** a `get` method that writes data; a `close` that fails if called twice; CLI flags that differ from common conventions; inconsistent handling of "not found" across an API.

## 11. Silence: say nothing when there is nothing to say

Noisy output hides the messages that matter and breaks composition.

**Red flags:** "entering function X" logs; CLIs printing banners or progress on success when not on a terminal.

**Fix:** results to stdout, problems to stderr, exit code 0 on success. Log what an operator would act on.

## 12. Repair: fail early and loudly

When something must fail, fail at the point of the problem with a clear message. Silent failures become corrupted data discovered weeks later.

**Red flags:** ignored error values; empty catch blocks; catching all exceptions and continuing; returning a default on failure without signaling; parsing config lazily so bad values surface hours after startup.

**Fix:** validate at boundaries and at startup. Propagate errors with context. Crash a process rather than run in a corrupt state.

## 13. Economy: developer time over machine time

Hardware is cheap; engineers' hours and attention are not. Prefer the approach that is faster to write, read, and fix, unless measurement shows a real performance problem.

**Red flags:** hand-rolled data structures where the standard library's work fine.

## 14. Generation: let programs write programs

Repetitive hand-written code is slow to write and easy to get subtly wrong.

**Red flags:** dozens of near-identical mocks, DTOs, serializers, or API clients typed by hand.

**Fix:** generate from a single source of truth (OpenAPI, protobuf, SQL schema, GraphQL schema). Commit or reproducibly build generated code and mark it as generated.

## 15. Optimization: make it work, then measure, then make it fast

Premature optimization adds complexity in places that usually don't matter.

**Red flags:** caching, pooling, or low-level tricks without a benchmark or profile.

**Fix:** write a benchmark, profile, change one thing, measure again.

## 16. Diversity: distrust "one true way"

No single language, framework, or pattern fits every problem.

**Red flags:** "we always use X" as the only justification; forcing a heavy architecture pattern onto a small script.

## 17. Extensibility: design for the future, but don't build it yet

Leave room for growth: versioned APIs, self-describing data formats, seams where change is likely. Don't implement imagined features.

**Red flags (too little):** wire formats with no version field; positional binary formats; APIs that can't add optional fields.
**Red flags (too much):** plugin systems with zero plugins; configuration for options nobody asked for.

---

## Rob Pike's rules of programming (paraphrased)

1. You can't tell where a program will spend its time. Bottlenecks appear in surprising places, so don't guess.
2. Measure. Don't tune for speed until you have measured, and even then only if one part dominates.
3. Fancy algorithms are slow when n is small, and n is usually small.
4. Fancy algorithms are buggier and harder to implement. Prefer simple algorithms and simple data structures.
5. Data dominates. Choose the right data structures and the algorithms usually become obvious.

Ken Thompson's corollary: when in doubt, use brute force.

## Doug McIlroy's summary

Write programs that do one thing and do it well. Write programs that work together. Use text streams, because text is a universal interface. In modern systems, read "text streams" as "simple, standard, well-documented formats" such as JSON, line-delimited logs, or HTTP.
