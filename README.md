# unclequin-skills

Agent skills for [Claude](https://claude.com) and Claude Code.

## Skills

| Skill | What it does |
|-------|--------------|
| [`unix-philosophy`](skills/unix-philosophy/SKILL.md) | Applies the Unix philosophy (Raymond's 17 rules, McIlroy's "do one thing well", Pike's rules on measurement and data) when designing, writing, refactoring, or reviewing code. Includes idiomatic guidance for Go, TypeScript/JavaScript, Python, Java/Kotlin, Rust, Haskell, and Lean 4. |

## Layout

```
.claude-plugin/
  marketplace.json          # Claude Code plugin marketplace: one plugin per skill
skills/
  unix-philosophy/
    SKILL.md                # entry point: when to use it and how to apply it
    references/rules.md     # all 17 rules, explanations, red flags
    references/languages/   # one file of idioms and tooling per language
templates/
  CLAUDE.md                 # project instructions that pair with the skill
```

## Install

### As a Claude Code plugin

This repository is a Claude Code plugin marketplace. Each skill is its own plugin. In a Claude Code session, install one in a single step:

```
/plugin install unix-philosophy --marketplace unclequin/unclequin-skills
```

Or add the marketplace once from your shell, then install skills by name:

```bash
claude plugin marketplace add unclequin/unclequin-skills
```

```bash
claude plugin install unix-philosophy@unclequin-skills
```

Plugin skills are namespaced by plugin, so the skill runs as `/unix-philosophy:unix-philosophy`. Claude also picks it up on its own when a task matches. Run `claude plugin marketplace update unclequin-skills` to get new versions.

### With npx

The [`skills`](https://github.com/vercel-labs/skills) CLI (Node.js 22.20 or later) installs skills into Claude Code and other coding agents:

```bash
npx skills add unclequin/unclequin-skills --skill unix-philosophy -a claude-code -g
```

`-g` installs for your user, so the skill is available in every project. Leave it off to install into the current project only. Leave off `--skill` and `-a` to pick skills and agents interactively.

### Manually, for Claude Code

Copy or symlink the skill folder into your personal skills directory:

```bash
git clone https://github.com/unclequin/unclequin-skills.git
```

```bash
ln -s "$PWD/unclequin-skills/skills/unix-philosophy" ~/.claude/skills/unix-philosophy
```

To share a skill with everyone working on one repository, put the folder in that repository's `.claude/skills/` instead.

### Claude apps

Zip the skill folder and upload it under **Settings → Capabilities → Skills**:

```bash
cd unclequin-skills/skills && zip -r unix-philosophy.zip unix-philosophy
```

## Using the CLAUDE.md template

[`templates/CLAUDE.md`](templates/CLAUDE.md) is a short set of always-on engineering principles for a project. Copy it into a repository's root (or merge it into an existing `CLAUDE.md`) and fill in the optional "Project stack" section. It keeps the core rules in context on every turn, while the `unix-philosophy` skill supplies the detailed rules and per-language examples when they are needed.

## Contributing a language

To add a language to `unix-philosophy`:

1. Add `skills/unix-philosophy/references/languages/<language>.md`, following the structure of the existing files.
2. List it under "Reference files" in [`skills/unix-philosophy/SKILL.md`](skills/unix-philosophy/SKILL.md) and in the skill's `description`.

## Adding a skill

Put it in `skills/<name>/SKILL.md`, then add a plugin entry for it to [`.claude-plugin/marketplace.json`](.claude-plugin/marketplace.json) with `"source": "./"` and `"skills": ["./skills/<name>"]`. Check the result with `claude plugin validate .`.
