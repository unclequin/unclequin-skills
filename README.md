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
├── examples/
│   └── functional-first/     # Tested sources of the code the language files show (not installed)
└── templates/
    ├── CLAUDE.md             # Short, always-on project rules (works without the skill)
    └── CODING_STANDARDS.md   # Judgement-call rules a review step reads
```

| Item | Status | What it does |
|------|--------|--------------|
| `unix-philosophy` | Ready | Design and review guidance: Raymond's 17 rules, McIlroy, Rob Pike, with examples for 7 languages |
| `templates/CLAUDE.md` | Ready | The core rules in one short file, imported globally or copied into a project |
| `functional-first` | Ready | Method for going from a real-world problem to correct code: say it, model it (sets, state machines), compose it, derive it, check it. Examples for 8 languages, including C |
| `templates/CODING_STANDARDS.md` | Ready | The rules a reviewer checks a change against, read only at review time |

The two skills split by level. `unix-philosophy` covers the design of a system: modules, interfaces, and failure reporting. `functional-first` covers the method inside a feature or function: business rules, reports, lifecycles, and making correct code fast without changing its behavior. They point to each other rather than repeating each other.

## Two ways to use it

You can use the skill, the CLAUDE.md template, or both. They load differently:

- **A skill does not load on every prompt.** Claude only keeps the skill's name and one-line description in context. The full SKILL.md loads when a request matches the description, and the reference files (like `languages/rust.md`) load only when Claude needs them. So installing the skill costs very little, but it only applies when Claude decides the task is relevant.
- **CLAUDE.md loads in full at the start of every Claude Code session.** It's always on, but every line costs context in every session, so it must stay short.

### When to use which

The template loads one of two ways: imported from your global `~/.claude/CLAUDE.md`, or copied into a project's `CLAUDE.md`. Pick one per machine, never both. With both, every session loads the rules twice, which costs context on every turn. The copy also drifts as the template changes, so the two versions disagree (different checklists, missing sections) and nothing says which one wins.

| Situation | Template | Skills |
|-----------|----------|--------|
| Solo developer, across all your own projects | Import globally | Install for all your projects |
| Team project, or CI agents that lack your global setup | Copy into the project and commit it | Commit into the project, or each person installs them |
| You also work on team projects that commit a copy | Copy it into your own projects too, and drop the global import | As above |
| Code reviews, design work, or multi-language projects where detailed examples help | Either way | Install |

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

## Option A: Load the template

No skill installation needed. Use one of the two setups below, never both (see [When to use which](#when-to-use-which)).

### Import it globally (solo developer)

Clone this repo once and import the template from your personal `~/.claude/CLAUDE.md`, so every project on your machine gets it:

```bash
git clone https://github.com/unclequin/unclequin-skills.git ~/unclequin-skills
echo '@~/unclequin-skills/templates/CLAUDE.md' >> ~/.claude/CLAUDE.md
```

To get updates, run `git pull` in `~/unclequin-skills`. If a project already has a pasted copy of the template, delete the copy from that project's `CLAUDE.md`.

### Copy it into the project (teams and CI)

The rules travel with the project's code, so teammates and CI agents get them without any setup.

1. With this repo cloned at `~/unclequin-skills`, write the template into the project's root folder. The first line records the template version: the last commit that changed it.

   ```bash
   cd ~/unclequin-skills && { echo "<!-- unclequin-skills templates/CLAUDE.md @ $(git log -1 --format=%h -- templates/CLAUDE.md) -->"; cat templates/CLAUDE.md; } > /path/to/your-project/CLAUDE.md
   ```

   If the project already has a `CLAUDE.md`, write to a temporary file instead, and put its contents at the top of the existing file, version line first.

2. Edit the commented "Project stack" block at the bottom: list the project's languages, formatters, linters, and build/test commands. Delete anything that doesn't apply.
3. Commit it so everyone on the team gets the same rules:

   ```bash
   cd /path/to/your-project
   git add CLAUDE.md
   git commit -m "Add CLAUDE.md with engineering principles"
   ```

### Update a copy

The version line says which template commit the copy came from. To bring the copy up to date:

1. Read the version from the copy's first line, for example `955f46d`, then pull this repo and show what changed in the template since then:

   ```bash
   git -C ~/unclequin-skills pull && git -C ~/unclequin-skills diff 955f46d HEAD -- templates/CLAUDE.md
   ```

2. Apply that diff to the project's `CLAUDE.md`, keeping the project's own lines, such as the "Project stack" block.
3. Set the version line to the new version, from `git -C ~/unclequin-skills log -1 --format=%h -- templates/CLAUDE.md`, and commit.

An empty diff in step 1 means the copy is current.

Tips:

- Keep it short. If a rule needs a long explanation or examples, it belongs in the skill, not in CLAUDE.md.
- For private notes in one project that shouldn't be committed, use `CLAUDE.local.md` in that project's root.
- The template works without the skill. If the skill is installed, Claude uses it for the detailed explanations.

## Option B: Install the skills

Install both skills. The template names both, so a session with only one of them has a pointer to a skill it can't load. Every method below installs both; use one method per machine.

### Claude Code plugin (recommended)

This repo is a Claude Code plugin marketplace, and each skill is its own plugin. In a Claude Code session, run:

```
/plugin install unix-philosophy --marketplace unclequin/unclequin-skills
```

```
/plugin install functional-first --marketplace unclequin/unclequin-skills
```

Or from your shell, add the marketplace once and then install both by name:

```bash
claude plugin marketplace add unclequin/unclequin-skills
```

```bash
claude plugin install unix-philosophy@unclequin-skills && claude plugin install functional-first@unclequin-skills
```

Plugin skills are namespaced by plugin, so you can run one as `/unix-philosophy:unix-philosophy` or `/functional-first:functional-first`. Claude also uses them on its own when a task matches. To get updates, run `claude plugin marketplace update unclequin-skills`.

### npx

The [`skills`](https://github.com/vercel-labs/skills) CLI (Node.js 22.20 or later) installs skills into Claude Code and other coding agents:

```bash
npx skills add unclequin/unclequin-skills --skill unix-philosophy -a claude-code -g
```

```bash
npx skills add unclequin/unclequin-skills --skill functional-first -a claude-code -g
```

`-g` installs them for all your projects. Leave it off to install into the current project only.

### Manually, for all your projects

```bash
git clone https://github.com/unclequin/unclequin-skills.git ~/unclequin-skills
mkdir -p ~/.claude/skills
for s in unix-philosophy functional-first; do ln -s ~/unclequin-skills/skills/$s ~/.claude/skills/$s; done
```

To get updates later, run `git pull` in `~/unclequin-skills`. The symlinks pick up the changes.

On Windows, copy the folders instead of linking them:

```powershell
foreach ($s in 'unix-philosophy','functional-first') { Copy-Item -Recurse $HOME\unclequin-skills\skills\$s $HOME\.claude\skills\$s }
```

### Manually, for one project only

Put the skills inside the project and commit them, so everyone who works on the project gets them:

```bash
mkdir -p /path/to/your-project/.claude/skills
cp -r skills/unix-philosophy skills/functional-first /path/to/your-project/.claude/skills/
```

### Claude.ai and the Claude desktop app

Zip each skill folder and upload both zips as custom skills in your Claude settings:

```bash
cd skills && zip -r unix-philosophy.zip unix-philosophy && zip -r functional-first.zip functional-first
```

The Claude desktop app also offers uploaded skills to its Code sessions, as `anthropic-skills:<name>`. An uploaded skill is a snapshot: after the repo changes, zip and upload it again.

### Check what's installed

In a Claude Code session or a Claude chat, send this one line. Both `unix-philosophy` and `functional-first` must be in the answer:

```
List the names of the skills available to you, one per line.
```

## Option C: Both

Load the template one way, imported globally or copied into the project (Option A), and install both skills (Option B). CLAUDE.md keeps the core rules active in every session and tells Claude which skill to use for which part of a task. The skills add the full workflow, per-language examples, and the review format when the task calls for them.

The template covers both skills in about 600 words. If a project only needs one, delete the other's section ("Building a feature" is functional-first; the rest is unix-philosophy) and its name in the first paragraph, to save context in every session.

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

To add a new skill, put it in `skills/<name>/SKILL.md`, then add a plugin entry for it to [`.claude-plugin/marketplace.json`](.claude-plugin/marketplace.json) with `"source": "./"` and `"skills": ["./skills/<name>"]`. Add it to every install method under Option B too, so a normal install still provides every skill the template names. Check the result with `claude plugin validate .`.

Edit files in this repo directly. Copying in an older zip or download of the repo brings back old paths, such as `unix-philosophy/` at the root instead of `skills/unix-philosophy/`.

## Credits

- Eric S. Raymond, *The Art of Unix Programming* (2003), "Basics of the Unix Philosophy"
- Doug McIlroy's summary of the Unix philosophy
- Rob Pike's rules of programming
- The `functional-first` skill is inspired by the method in Pieter Hartel and Henk Muller, *Functional C* (Addison-Wesley, 1997). Its transformation catalog draws on Burstall and Darlington's fold/unfold work (1977) and the Bird–Meertens formalism

All explanations and examples in this repo are written in our own words.
