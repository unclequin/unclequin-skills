# unclequin-skills

Claude skills and project templates for software development, based on the Unix philosophy. They work across Go, TypeScript/JavaScript, Python, Java/Kotlin, Rust, Haskell, and Lean 4.

## What's in this repo

```
unclequin-skills/
├── .claude-plugin/
│   └── marketplace.json      # Claude Code plugin marketplace: one plugin per skill
├── skills/
│   └── unix-philosophy/      # Skill: design rules + idiomatic examples per language
│       ├── SKILL.md
│       └── references/
│           ├── rules.md
│           └── languages/    # go, typescript, python, java, rust, haskell, lean4
└── templates/
    └── CLAUDE.md             # Short, always-on project rules (works without the skill)
```

| Item | Status | What it does |
|------|--------|--------------|
| `unix-philosophy` | Ready | Design and review guidance: Raymond's 17 rules, McIlroy, Rob Pike, with examples for 7 languages |
| `templates/CLAUDE.md` | Ready | The core rules in one short file for a project's root |
| `functional-first` | Planned | Method for going from a real-world problem to correct code: say it, model it (sets, state machines), compose it, derive it, check it |

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

## Option B: Install the skill

### Claude Code plugin (recommended)

This repo is a Claude Code plugin marketplace, and each skill is its own plugin. In a Claude Code session, install it in one step:

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

Plugin skills are namespaced by plugin, so you can run it as `/unix-philosophy:unix-philosophy`. Claude also uses it on its own when a task matches. To get updates, run `claude plugin marketplace update unclequin-skills`.

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

Copy `templates/CLAUDE.md` into the project (Option A) and install the skill (Option B). CLAUDE.md keeps the core rules active in every session, and the skill adds per-language examples and the full review format when the task calls for them.

## Updating this repo

When a skill changes:

```bash
git add skills templates
git commit -m "Describe the change"
git push
```

If you change a rule in the skill, check whether `templates/CLAUDE.md` needs the same change, so the two don't disagree.

To add a new skill, put it in `skills/<name>/SKILL.md`, then add a plugin entry for it to [`.claude-plugin/marketplace.json`](.claude-plugin/marketplace.json) with `"source": "./"` and `"skills": ["./skills/<name>"]`. Check the result with `claude plugin validate .`.

Edit files in this repo directly. Copying in an older zip or download of the repo brings back old paths, such as `unix-philosophy/` at the root instead of `skills/unix-philosophy/`.

## Credits

- Eric S. Raymond, *The Art of Unix Programming* (2003), "Basics of the Unix Philosophy"
- Doug McIlroy's summary of the Unix philosophy
- Rob Pike's rules of programming
- The planned `functional-first` skill is inspired by the method in Pieter Hartel and Henk Muller, *Functional C* (Addison-Wesley, 1997)

All explanations and examples in this repo are written in our own words.
