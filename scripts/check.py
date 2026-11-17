#!/usr/bin/env python3
"""Check that the repo's own claims about itself are true.

The rule: every skill folder under skills/ is listed in the marketplace
manifest and in the README tree, each plugin's source is plugins/<name>
holding only a link to its skill, every path the README tree names exists,
no SKILL.md lives outside skills/<name>/, and the README's word count for
templates/CLAUDE.md is the real count rounded to the nearest 50.

Each check is a pure function from values to a list of error strings.
main() does all the reading and runs `claude plugin validate`.
Silent on success; errors go to stderr and the exit code is 1.
"""

import json
import os
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MANIFEST = ".claude-plugin/marketplace.json"
TEMPLATE = "templates/CLAUDE.md"
SKILL_FILE = re.compile(r"^skills/[^/]+/SKILL\.md$")
TREE_ENTRY = re.compile(r"^(?P<indent>[│ ]*)[├└]── (?P<name>\S+)")
WORD_CLAIM = re.compile(r"about ([\d,]+) words")
# "about N words" is read as: N is the real count rounded to the nearest 50.
ROUNDING = 50


def expected_plugin_files(names: set[str]) -> dict[str, str]:
    """The files under plugins/ for these skills: one symlink per skill.

    The desktop app counts a plugin's skills by looking in its skills/
    folder, and installing a plugin copies only its source folder. So each
    plugin's source is plugins/<name>, holding skills/<name> as a link to
    the real skill folder, and nothing else.
    """
    return {
        f"plugins/{n}/skills/{n}": f"../../../skills/{n}" for n in sorted(names)
    }


def check_plugins(manifest: dict, plugin_files: dict[str, str | None], folders: set[str]) -> list[str]:
    """Each skill folder has one plugin, sourced from plugins/<name>.

    plugin_files maps each file under plugins/ to its symlink target
    (None for a regular file).
    """
    names = {f.removeprefix("skills/") for f in folders}
    plugins = {p["name"]: p for p in manifest["plugins"]}
    errors = [
        f"{MANIFEST}: plugin {n} has no folder skills/{n}"
        for n in sorted(plugins.keys() - names)
    ] + [
        f"{MANIFEST}: skills folder skills/{n} has no plugin"
        for n in sorted(names - plugins.keys())
    ]
    for n, plugin in sorted(plugins.items()):
        if plugin.get("source") != f"./plugins/{n}":
            errors.append(f"{MANIFEST}: plugin {n} should have source ./plugins/{n}, not {plugin.get('source')}")
        if "skills" in plugin:
            errors.append(f"{MANIFEST}: plugin {n} should have no skills field; it uses its source's skills/ folder")
    expected = expected_plugin_files(names & plugins.keys())
    for path, target in sorted(expected.items()):
        if path not in plugin_files:
            errors.append(f"{path}: missing; create it with ln -s {target} {path}")
        elif plugin_files[path] != target:
            errors.append(f"{path}: should be a symlink to {target}")
    errors += [
        f"{path}: unexpected file under plugins/; each plugin holds only its skill link"
        for path in sorted(plugin_files.keys() - expected.keys())
    ]
    return errors


def check_skill_file_locations(tracked: list[str]) -> list[str]:
    return [
        f"{p}: a SKILL.md must live at skills/<name>/SKILL.md"
        for p in tracked
        if p.endswith("SKILL.md") and not SKILL_FILE.match(p)
    ]


def readme_tree_paths(readme: str) -> list[str]:
    """Paths named by the README's first fenced block, read as a tree drawing.

    Each nesting level is four columns wide, so an entry's depth is its
    indent width divided by four. The block's first line is the repo root.
    """
    block = readme.split("```")[1]
    paths: list[str] = []
    parents: list[str] = []
    for line in block.splitlines():
        entry = TREE_ENTRY.match(line)
        if not entry:
            continue
        depth = len(entry["indent"]) // 4
        parents = parents[:depth] + [entry["name"].rstrip("/")]
        paths.append("/".join(parents))
    return paths


def check_readme_tree(tree: list[str], existing: set[str], folders: set[str]) -> list[str]:
    return [
        f"README.md: the repo tree names {p}, which does not exist"
        for p in tree
        if p not in existing
    ] + [
        f"README.md: the repo tree omits the skill folder {p}"
        for p in sorted(folders - set(tree))
    ]


def check_word_count(readme: str, actual: int) -> list[str]:
    claims = [int(n.replace(",", "")) for n in WORD_CLAIM.findall(readme)]
    if not claims:
        return [f"README.md: no 'about N words' claim found for {TEMPLATE}"]
    expected = round(actual / ROUNDING) * ROUNDING
    return [
        f"README.md: says about {claim} words, but {TEMPLATE} has {actual} "
        f"(write about {expected})"
        for claim in claims
        if claim != expected
    ]


def validate_manifest() -> list[str]:
    try:
        result = subprocess.run(
            ["claude", "plugin", "validate", "."],
            cwd=ROOT, capture_output=True, text=True,
        )
    except FileNotFoundError:
        return ["claude plugin validate: the `claude` CLI is not installed"]
    if result.returncode == 0:
        return []
    return [f"claude plugin validate failed:\n{result.stdout}{result.stderr}".rstrip()]


def main() -> int:
    # Untracked files count too, so a stray copy is caught before it is committed.
    tracked = subprocess.run(
        ["git", "ls-files", "--cached", "--others", "--exclude-standard"],
        cwd=ROOT, capture_output=True, text=True, check=True,
    ).stdout.splitlines()
    # Every tracked file and each of its parent folders.
    existing = {
        "/".join(parts[:i])
        for parts in (p.split("/") for p in tracked)
        for i in range(1, len(parts) + 1)
    }
    folders = {f"skills/{p.name}" for p in (ROOT / "skills").iterdir() if p.is_dir()}
    plugin_files = {
        p: os.readlink(ROOT / p) if (ROOT / p).is_symlink() else None
        for p in tracked
        if p.startswith("plugins/")
    }
    readme = (ROOT / "README.md").read_text()
    manifest = json.loads((ROOT / MANIFEST).read_text())
    words = len((ROOT / TEMPLATE).read_text().split())

    errors = (
        validate_manifest()
        + check_plugins(manifest, plugin_files, folders)
        + check_skill_file_locations(tracked)
        + check_readme_tree(readme_tree_paths(readme), existing, folders)
        + check_word_count(readme, words)
    )
    for error in errors:
        print(error, file=sys.stderr)
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
