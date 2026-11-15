# unclequin-skills

Instructions for agents working on this repository. This is not the shipped rules template: that is `templates/CLAUDE.md`, which users copy or import into their own projects. Don't merge the two.

## Check

Run `scripts/check.py` before committing; CI runs it on every pull request.

## Review

When reviewing a change here, apply the root `CODING_STANDARDS.md`. `templates/CODING_STANDARDS.md` is the shipped one, for users' projects.

## Agent skills

### Issue tracker

Issues live in GitHub Issues for `unclequin/unclequin-skills`, managed with the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

The default five-role vocabulary: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: one root `GLOSSARY.md` and `docs/adr/`, created when first needed. See `docs/agents/domain.md`.
