# unclequin-skills

Claude skills and project templates for software development, based on the Unix philosophy and on functional-first programming. They work across Go, TypeScript/JavaScript, Python, Java/Kotlin, Rust, Haskell, and Lean 4, and `functional-first` also covers C.

## What's in this repo

```
unclequin-skills/
├── .claude-plugin/
│   └── marketplace.json      # Claude Code plugin marketplace: one plugin per skill
├── skills/
│   ├── unix-philosophy/      # Skill: design rules + idiomatic examples per language
│   │   ├── SKILL.md
│   │   └── references/
│   │       ├── rules.md
│   │       └── languages/    # go, typescript, python, java, rust, haskell, lean4
│   └── functional-first/     # Skill: from a real-world problem to correct code
│       ├── SKILL.md          # the five-step workflow
│       └── references/
│           ├── modeling.md   # sets for rules, state machines for lifecycles
│           ├── composition.md
│           ├── derivation.md # spec to fast code, and the behavior traps
│           ├── testing.md    # the spec as test oracle, property-based tests
│           └── languages/    # go, typescript, python, java, rust, haskell, lean4, c
└── templates/
    ├── CLAUDE.md             # Short, always-on project rules (works without the skill)
    └── CODING_STANDARDS.md   # Judgement-call rules a review step reads
```

| Item | Status | What it does |
|------|--------|--------------|
| `unix-philosophy` | Ready | Design and review guidance: Raymond's 17 rules, McIlroy, Rob Pike, with examples for 7 languages |
| `templates/CLAUDE.md` | Ready | The core rules in one short file for a project's root |
| `functional-first` | Ready | Method for going from a real-world problem to correct code: say it, model it (sets, state machines), compose it, derive it, check it. Examples for 8 languages, including C |
| `templates/CODING_STANDARDS.md` | Ready | The rules a reviewer checks a change against, read only at review time |

The two skills split by level. `unix-philosophy` covers the design of a system: modules, interfaces, and failure reporting. `functional-first` covers the method inside a feature or function: business rules, reports, lifecycles, and making correct code fast without changing its behavior. They point to each other rather than repeating each other.

## Two ways to use it

You can use the skill, the CLAUDE.md template, or both. They load differently:

- **A skill does not load on every prompt.** Claude only keeps the skill's name and one-line description in context. The full SKILL.md loads when a request matches the description, and the reference files (like `languages/rust.md`) load only when Claude needs them. So installing the skill costs very little, but it only applies when Claude decides the task is relevant.
- **CLAUDE.md loads in full at the start of every Claude Code session.** It's always on, but every line costs context in every session, so it must stay short.

### When to use which

| Situation | Use |
|-----------|-----|
| Small project, script, or prototype | CLAUDE.md only |
| You want the rules guaranteed in every session, without relying on the skill being triggered | CLAUDE.md only |
| Teammates or CI environments don't have the skill installed | CLAUDE.md only (it's committed with the code) |
| Code reviews, design work, or multi-language projects where detailed examples help | Skill |
| Main team projects | Both: CLAUDE.md for the short always-on rules, the skill for detail when needed |

### Using both skills in one prompt

Claude picks skills by matching your request to each skill's description, and it can load more than one in the same turn. A request that touches both levels, such as a new module plus its business rules, usually triggers both on its own.

To make sure, name them in the prompt. Plain words work:

```
Use the unix-philosophy and functional-first skills. Add a billing module:
it computes monthly revenue from paid orders, except refunded ones, and
exposes it through the existing HTTP API.
```

A message can start with only one slash command, so invoke one skill with the command and name the other in the text:

```
/unix-philosophy:unix-philosophy Design the billing module's interface,
then use the functional-first skill to implement the revenue rule.
```

The two skills split the work by level: `unix-philosophy` decides the parts and their interfaces, then `functional-first` builds the code inside each part. To have Claude do this on every task without being asked, use the CLAUDE.md template (Option C): its first paragraph tells Claude when to use each skill.

## Option A: CLAUDE.md only

No installation needed. The rules travel with the project's code.

1. Copy the template into the project's root folder:

   ```bash
   cp templates/CLAUDE.md /path/to/your-project/CLAUDE.md
   ```

2. Edit the commented "Project stack" block at the bottom: list the project's languages, formatters, linters, and build/test commands. Delete anything that doesn't apply.
3. Commit it so everyone on the team gets the same rules:

   ```bash
   cd /path/to/your-project
   git add CLAUDE.md
   git commit -m "Add CLAUDE.md with engineering principles"
   ```

Tips:

- Keep it short. If a rule needs a long explanation or examples, it belongs in the skill, not in CLAUDE.md.
- For personal rules that apply to all your projects, put them in `~/.claude/CLAUDE.md` instead.
- For private notes in one project that shouldn't be committed, use `CLAUDE.local.md` in that project's root.
- The template works without the skill. If the skill is installed, Claude uses it for the detailed explanations.

## Option B: Install the skills

The commands below use `unix-philosophy`. To install `functional-first`, use the same commands with `functional-first` in its place.

### Claude Code plugin (recommended)

This repo is a Claude Code plugin marketplace, and each skill is its own plugin. In a Claude Code session, install one in a single step:

```
/plugin install unix-philosophy --marketplace unclequin/unclequin-skills
```

Or from your shell, add the marketplace once and then install by name:

```bash
claude plugin marketplace add unclequin/unclequin-skills
```

```bash
claude plugin install unix-philosophy@unclequin-skills
```

```bash
claude plugin install functional-first@unclequin-skills
```

Plugin skills are namespaced by plugin, so you can run one as `/unix-philosophy:unix-philosophy` or `/functional-first:functional-first`. Claude also uses them on its own when a task matches. To get updates, run `claude plugin marketplace update unclequin-skills`.

### npx

The [`skills`](https://github.com/vercel-labs/skills) CLI (Node.js 22.20 or later) installs skills into Claude Code and other coding agents:

```bash
npx skills add unclequin/unclequin-skills --skill unix-philosophy -a claude-code -g
```

`-g` installs it for all your projects. Leave it off to install into the current project only.

### Manually, for all your projects

```bash
git clone https://github.com/unclequin/unclequin-skills.git ~/unclequin-skills
mkdir -p ~/.claude/skills
ln -s ~/unclequin-skills/skills/unix-philosophy ~/.claude/skills/unix-philosophy
```

To get updates later, run `git pull` in `~/unclequin-skills`. The symlink picks up the changes.

On Windows, copy the folder instead of linking it:

```powershell
Copy-Item -Recurse $HOME\unclequin-skills\skills\unix-philosophy $HOME\.claude\skills\unix-philosophy
```

### Manually, for one project only

Put the skill inside the project and commit it, so everyone who works on the project gets it:

```bash
mkdir -p /path/to/your-project/.claude/skills
cp -r skills/unix-philosophy /path/to/your-project/.claude/skills/
```

### Claude.ai

Zip the `skills/unix-philosophy` folder and upload it as a custom skill in your Claude settings:

```bash
cd skills && zip -r unix-philosophy.zip unix-philosophy
```

## Option C: Both

Copy `templates/CLAUDE.md` into the project (Option A) and install both skills (Option B). CLAUDE.md keeps the core rules active in every session and tells Claude which skill to use for which part of a task. The skills add the full workflow, per-language examples, and the review format when the task calls for them.

The template covers both skills in about 700 words. If a project only needs one, delete the other's section ("Building a feature" is functional-first; the rest is unix-philosophy) to save context in every session.

## Review: standards file and checks

The rules sit at three stages, each read or run by a different reader:

- **`CLAUDE.md` loads on every turn**, so the agent writing the code has it the whole time. It holds the principles that shape code as it is written, and every line must change what the agent does. It costs context on every turn, so it holds no checklist.
- **`CODING_STANDARDS.md` is read at review.** A review step (a reviewer agent, a review skill, or a CI review prompt) reads it once per change and checks the change against it. It holds the judgement calls a tool can't make. The template's "Review" line points agents at it.
- **Checks run on every commit or in CI**, with no reading at all. They hold the mechanical rules: formatting, lint, and ignored errors.

Copy the standards file into the project's root, next to `CLAUDE.md`. It loads only at review, so a copy costs nothing per turn. Start it with a version line too, so drift shows:

```bash
cd ~/unclequin-skills && { echo "<!-- unclequin-skills templates/CODING_STANDARDS.md @ $(git log -1 --format=%h -- templates/CODING_STANDARDS.md) -->"; cat templates/CODING_STANDARDS.md; } > /path/to/your-project/CODING_STANDARDS.md
```

Older versions of the template ended with an 8-item "Before finishing any change, check" list. Here is where each item went:

| Old checklist item | Now |
|--------------------|-----|
| Each new unit described in one sentence | Standards |
| All errors handled, with context and the original cause | Check for ignored and swallowed errors; standards for the context and cause |
| No abstraction with only one implementation and no test need | Standards |
| No noisy logging on the success path | Standards, plus a lint for stray prints where the language has one |
| Nothing optimized without measuring | Standards |
| The language's own conventions and formatter | Check: formatter and linter |
| The top function's doc comment states the rule and the reading of each ambiguous word | Standards |
| A spec-equals-fast test for code made faster | Standards |

Wire the checks into a pre-commit hook or CI so they fail the build. One example command per language the skills cover:

| Language | Example check | What it catches beyond formatting |
|----------|---------------|-----------------------------------|
| Go | `test -z "$(gofmt -l .)" && golangci-lint run` | `errcheck` (on by default) flags ignored error values |
| TypeScript/JavaScript | `npx prettier --check . && npx eslint . --max-warnings 0` | Turn on `no-empty`, `@typescript-eslint/no-floating-promises`, and `no-console` |
| Python | `ruff format --check . && ruff check --extend-select BLE,S110,T20 .` | `BLE` blind `except`, `S110` `try`-`except`-`pass`, `T20` stray `print` |
| Java | `./gradlew spotlessCheck pmdMain` | PMD's `EmptyCatchBlock` |
| Kotlin | `ktlint && detekt` | detekt's `SwallowedException` and `EmptyCatchBlock` |
| Rust | `cargo fmt --check && cargo clippy --all-targets -- -D warnings` | `unused_must_use` turns an ignored `Result` into an error |
| Haskell | `ormolu --mode check $(git ls-files '*.hs') && hlint .` | Build with `-Wall -Werror`: `-Wunused-do-bind` flags discarded results |
| Lean 4 | `lake build && lake exe runLinter` (Batteries) | No standard formatter; the compiler already rejects a discarded non-`Unit` result in `do` |
| C | `clang-format --dry-run --Werror $(git ls-files '*.c' '*.h') && clang-tidy --checks='bugprone-*,cert-err33-c' $(git ls-files '*.c') --` | `cert-err33-c` flags unchecked return values of standard functions |

List the project's own commands in the template's "Project stack" block, so agents run the same checks before they finish.

## Updating this repo

When a skill changes:

```bash
git add skills templates
git commit -m "Describe the change"
git push
```

If you change a rule in the skill, check whether `templates/CLAUDE.md` or `templates/CODING_STANDARDS.md` needs the same change, so they don't disagree. A rule goes in only one of the two templates: principles that shape code as it is written in `CLAUDE.md`, judgement calls a reviewer checks in `CODING_STANDARDS.md`.

To add a new skill, put it in `skills/<name>/SKILL.md`, then add a plugin entry for it to [`.claude-plugin/marketplace.json`](.claude-plugin/marketplace.json) with `"source": "./"` and `"skills": ["./skills/<name>"]`. Check the result with `claude plugin validate .`.

Edit files in this repo directly. Copying in an older zip or download of the repo brings back old paths, such as `unix-philosophy/` at the root instead of `skills/unix-philosophy/`.

## Credits

- Eric S. Raymond, *The Art of Unix Programming* (2003), "Basics of the Unix Philosophy"
- Doug McIlroy's summary of the Unix philosophy
- Rob Pike's rules of programming
- The `functional-first` skill is inspired by the method in Pieter Hartel and Henk Muller, *Functional C* (Addison-Wesley, 1997). Its transformation catalog draws on Burstall and Darlington's fold/unfold work (1977) and the Bird–Meertens formalism

All explanations and examples in this repo are written in our own words.
