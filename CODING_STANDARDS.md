# Coding standards for this repository

Read this when reviewing a change to this repo. It is not the shipped standards file: that is `templates/CODING_STANDARDS.md`, which users copy into their own projects.

It holds the judgement calls a reviewer makes. The manifest, the skill folders, the README tree and word count, and the install commands are enforced by `scripts/check.py` and `scripts/install-test.sh`, so leave those to them. Apply every rule to every file the change adds or touches, and report each break with its file, line, and the rule it breaks.

## Skills

- Every file under a skill's `references/` is reached by a pointer in that skill's `SKILL.md`, and the pointer says when to read the file.
- Each line added to a skill's `description` names a distinct case that should trigger the skill. A synonym for a case already listed is cut.
- A change to a skill's steps or description comes with a comparison: the same task run by an agent with and without the change, and what differed.
- A rule or example added to one language file is added to every language file of that skill, or the change says why that language is left out.
- Code in a reference file was compiled and tested as shown, and the change says with which commands.

## The template

- Each line added to `templates/CLAUDE.md` changes what an agent does by default. A line the agent already follows without being told is cut.
- A rule that appears in both `templates/CLAUDE.md` and a skill uses the same words in both. A change to one updates the other in the same change.
- A rule a formatter, linter, or test could enforce goes in the README's checks table, and stays out of both templates.

## README

- Every install method covers every skill.
- A claim the README makes about the repo (a count, a path, a command) is either checked by `scripts/check.py` or true by inspection in this change.

## Scripts

- Each check is a pure function from values to a list of errors; reading files and running commands happens in one place.
- A script prints nothing on success, and on failure names the file or command at fault.

## Sources

- Explanations and examples are written in our own words. A source is credited by name, and its text is not copied.
