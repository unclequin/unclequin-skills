---
name: unix-philosophy
description: Apply the Unix philosophy (Eric S. Raymond's 17 rules, McIlroy's "do one thing well", Rob Pike's rules on measurement and data) when designing, writing, refactoring, or reviewing software in any programming language. Use this skill whenever the user asks to design a module, service, CLI, API, library, or package; write or refactor non-trivial code; review a pull request or code for quality; split a large function, class, or service; decide between a clever and a simple approach; or asks about modularity, composability, simplicity, error handling, or "clean" design, even if they never mention Unix. Works for Go, TypeScript/JavaScript, Python, Java/Kotlin, Rust, Haskell, Lean 4 (programs and proofs), and other languages.
---

# Unix Philosophy for Software Development

The Unix philosophy is a set of design habits that keep software simple, composable, and easy to debug. The core idea fits in one line: **build small, clear parts that do one thing well and connect through simple interfaces.** Everything else follows from that, and from KISS (Keep It Simple, Stupid).

The rules are language-independent. What changes between languages is *how* each rule looks in idiomatic code. Always express the rules in the idioms of the language you are working in, not in the idioms of another language.

Use this skill as a lens, not a rulebook. The rules sometimes pull against each other (Economy vs. Optimization, Extensibility vs. Simplicity). When they conflict, prefer the choice that a tired engineer can understand and debug at 3 a.m.

## Reference files

- `references/rules.md`: all 17 rules with language-neutral explanations and red flags. Read it for design or code reviews, or when you need to explain *why* a change is better.
- `references/languages/<language>.md`: idiomatic examples and tooling for a specific language. Before writing or reviewing code, read the file for the language in use:
  - `go.md`: Go
  - `typescript.md`: TypeScript and JavaScript (Node.js and browser)
  - `python.md`: Python
  - `java.md`: Java and Kotlin
  - `rust.md`: Rust
  - `haskell.md`: Haskell
  - `lean4.md`: Lean 4, for both programs and proofs (lemmas, tactics, specifications)
- If no file exists for the language in use, apply the rules using that language's standard conventions, standard library abstractions, and community style guide. The questions in "Mapping rules to any language" below tell you what to look for.

When a project mixes languages (e.g., a Go backend with a TypeScript frontend), read each relevant language file and apply each language's idioms to its own code. Keep the boundary between them (APIs, message formats, files) simple, standard, and versioned.

## The rules at a glance

| # | Rule | One-line meaning |
|---|------|------------------|
| 1 | Modularity | Simple parts, clean interfaces |
| 2 | Clarity | Clear beats clever |
| 3 | Composition | Design parts to connect with other parts |
| 4 | Separation | Separate policy from mechanism, interface from engine |
| 5 | Simplicity | Add complexity only when forced to |
| 6 | Parsimony | Write a big program only when nothing smaller works |
| 7 | Transparency | Make internal state easy to see and debug |
| 8 | Robustness | Robustness comes from simplicity and transparency |
| 9 | Representation | Put knowledge in data so logic stays simple |
| 10 | Least Surprise | Do the most expected thing in interfaces |
| 11 | Silence | Say nothing when there is nothing surprising to say |
| 12 | Repair | Fail early and loudly |
| 13 | Economy | Developer time costs more than machine time |
| 14 | Generation | Generate repetitive code instead of hand-writing it |
| 15 | Optimization | Make it work, then measure, then make it fast |
| 16 | Diversity | Distrust "one true way" claims |
| 17 | Extensibility | Leave room to grow without building it now |

Plus Rob Pike's performance rules: you can't guess where time goes, so measure; fancy algorithms lose when n is small (and n is usually small); fancy algorithms have more bugs; data structures matter more than algorithms.

## Mapping rules to any language

For a language without a reference file, answer these questions from that language's own ecosystem:

- **Composition:** What is the language's standard abstraction for streams, collections, or callables (e.g., iterators, streams, readers, functions)? Accept that instead of a concrete source like a file path.
- **Small interfaces:** How does the language express a contract (interface, protocol, trait, type, abstract class)? Keep contracts narrow.
- **Repair:** What is the idiomatic error mechanism (error values, exceptions, Result types)? Use it to fail fast, add context, and never swallow failures.
- **Transparency:** How are errors given context (wrapping, exception chaining, causes)? How is structured logging done?
- **Least Surprise:** What are the naming, formatting, and API conventions of the official style guide?
- **Generation:** What code generators are standard (schema-to-code, mocks, serializers)?
- **Optimization:** What are the standard benchmarking and profiling tools?

## How to apply it

### When designing (module, service, package, class, CLI, API)

1. **State the one job.** Write one sentence describing what this unit does. If the sentence needs "and", consider splitting it.
2. **Design the interface first.** Keep it small, ideally one to three operations. Accept the most general input type that works; return specific, well-defined results.
3. **Pick the data shape before the algorithm.** Ask what data structure would make the logic obvious. Tables, maps, and config often replace branching code.
4. **Separate policy from mechanism.** Business rules and configuration ("what") live apart from the engine that executes them ("how"), so either can change alone.
5. **Plan for composition.** Prefer plain, standard formats (text, JSON, stdin/stdout, HTTP, the language's standard abstractions) so other tools and languages can consume the output.
6. **Decide the failure behavior.** Validate inputs at the boundary and report errors immediately with context. Never fail silently.

### When writing code

- Write the simplest version that works. No speculative abstractions, plugin systems, or generic frameworks "for later".
- Follow the language's idioms and official style guide. Don't import patterns from another language (e.g., Java-style class hierarchies in Go, or Go-style error returns in Python).
- Name things so a junior engineer understands them without comments. Use comments to explain *why*, not *what*.
- Keep functions short and focused. Extract when a function does two separable things, not merely when it is long.
- Stay quiet on success: no chatty logs or prints in normal flow. Log what an operator would act on.
- Fail fast: handle errors where they happen and add context about what was being attempted.
- Optimize only with a benchmark or profile in hand.

### When reviewing code

Walk through the code and check it against the red flags below. For each issue found, report:

```
[Rule name] file:line: what the problem is
Why it matters: one sentence on the real cost (bugs, debugging time, coupling)
Suggestion: the concrete, smaller change, written in the code's own language
```

Order findings by impact (correctness and failure handling first, style last). Also note what the code does *well* by the same rules, since it helps people learn the pattern, not just avoid mistakes. Don't flag things just to fill the list; a short review of real issues beats a long one of nitpicks.

### Red flags (quick checklist)

- A function, class, module, or service whose description needs "and" → Modularity
- Clever one-liners, deep nesting, or magic values → Clarity
- Output only usable by one caller; custom formats where standard ones exist; functions that take a file path instead of a stream or collection → Composition
- Business rules hardcoded inside I/O, transport, or UI code → Separation
- Wide interfaces; abstraction layers with one implementation and no test need → Simplicity
- A new service or framework where a function or module would do → Parsimony
- Errors without context; no way to inspect state → Transparency
- Long if/else or switch chains encoding rules that could be a table → Representation
- Functions with hidden side effects; names that don't match behavior; breaking language conventions → Least Surprise
- Logging every step on success → Silence
- Swallowed errors (ignored error values, empty catch blocks, bare `except: pass`), returning defaults on failure, silent infinite retries → Repair
- Hand-written repetitive boilerplate (mocks, DTOs, serializers, API clients) → Generation
- Optimization without a benchmark; complex caching before measuring → Optimization
- Config options, hooks, or generics for imagined future needs → Simplicity vs. Extensibility (keep the door open, don't build the room)

## Communicating with the user

- Name the rule when it helps learning, but lead with the practical consequence ("this hides the real error, so debugging will be slow") rather than citing doctrine.
- Show the smaller, clearer version in code, in the same language as the code under discussion.
- When a rule doesn't fit the situation (e.g., a hot path that truly needs optimization, a framework the team already standardized on), say so. The rules serve the code, not the other way round. That is Rule 16 (Diversity).
