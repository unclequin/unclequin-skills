# unclequin-skills

Agent skills for [Claude](https://claude.com) and Claude Code.

## Skills

| Skill | What it does |
|-------|--------------|
| [`unix-philosophy`](unix-philosophy/SKILL.md) | Applies the Unix philosophy (Raymond's 17 rules, McIlroy's "do one thing well", Pike's rules on measurement and data) when designing, writing, refactoring, or reviewing code. Includes idiomatic guidance for Go, TypeScript/JavaScript, Python, Java/Kotlin, Rust, Haskell, and Lean 4. |

## Layout

```
unix-philosophy/
  SKILL.md                  # entry point: when to use it and how to apply it
  references/rules.md       # all 17 rules, explanations, red flags
  references/languages/     # one file of idioms and tooling per language
templates/
  CLAUDE.md                 # project instructions that pair with the skill
```

## Install

### Claude Code

Copy or symlink a skill folder into your personal skills directory, so it's available in every project:

```bash
git clone https://github.com/unclequin/unclequin-skills.git
```

```bash
ln -s "$PWD/unclequin-skills/unix-philosophy" ~/.claude/skills/unix-philosophy
```

To share a skill with everyone working on one repository, put the folder in that repository's `.claude/skills/` instead.

### Claude apps

Zip the skill folder and upload it under **Settings → Capabilities → Skills**:

```bash
cd unclequin-skills && zip -r unix-philosophy.zip unix-philosophy
```

## Using the CLAUDE.md template

[`templates/CLAUDE.md`](templates/CLAUDE.md) is a short set of always-on engineering principles for a project. Copy it into a repository's root (or merge it into an existing `CLAUDE.md`) and fill in the optional "Project stack" section. It keeps the core rules in context on every turn, while the `unix-philosophy` skill supplies the detailed rules and per-language examples when they are needed.

## Contributing a language

To add a language to `unix-philosophy`:

1. Add `unix-philosophy/references/languages/<language>.md`, following the structure of the existing files.
2. List it under "Reference files" in [`unix-philosophy/SKILL.md`](unix-philosophy/SKILL.md) and in the skill's `description`.
