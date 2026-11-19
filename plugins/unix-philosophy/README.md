# Unix philosophy

Design guidance for software in any language: build small, clear parts that do one thing well and connect through simple interfaces.

## What it does

The skill gives Claude Eric S. Raymond's 17 rules of the Unix philosophy, McIlroy's "do one thing well", and Rob Pike's rules on measurement and data, each with idiomatic examples for Go, TypeScript, Python, Java/Kotlin, Rust, Haskell, Elixir, and Lean 4. Claude applies them in the idioms of the language at hand.

It covers the design of a system: how to split it into modules, what their interfaces look like, and how failures are reported. For the method inside a single feature (business rules, lifecycles, making correct code fast), install the companion plugin `functional-first`.

## When Claude uses it

Claude loads the skill on its own when you ask it to:

- design a module, service, CLI, API, library, or package
- write or refactor non-trivial code
- review a pull request or code for quality
- split a large function, class, or service
- choose between a clever and a simple approach

To call it by name, run `/unix-philosophy:unix-philosophy`.

## Install

In a Claude Code session:

```
/plugin install unix-philosophy --marketplace unclequin/unclequin-skills
```

## More

Source, the always-on rules template, and install options: https://github.com/unclequin/unclequin-skills
