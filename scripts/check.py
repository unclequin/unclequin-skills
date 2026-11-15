#!/usr/bin/env python3
"""Check that the repo's own claims about itself are true.

The rule: every skill folder under skills/ is listed in the marketplace
manifest and in the README tree, every path the README tree names exists,
no SKILL.md lives outside skills/<name>/, and the README's word count for
templates/CLAUDE.md is the real count rounded to the nearest 50.

Each check is a pure function from values to a list of error strings.
main() does all the reading and runs `claude plugin validate`.
Silent on success; errors go to stderr and the exit code is 1.
"""

import json
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


def manifest_skills(manifest: dict) -> set[str]:
    """Skill folders the manifest lists, as repo-relative paths."""
    return {
        skill.removeprefix("./").rstrip("/")
        for plugin in manifest["plugins"]
        for skill in plugin.get("skills", [])
    }


def check_manifest_matches_folders(listed: set[str], folders: set[str]) -> list[str]:
    return [
        f"{MANIFEST}: lists {p}, which is not a folder under skills/"
        for p in sorted(listed - folders)
    ] + [
        f"{MANIFEST}: skills folder {p} is not listed in any plugin"
        for p in sorted(folders - listed)
    ]


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
    readme = (ROOT / "README.md").read_text()
    manifest = json.loads((ROOT / MANIFEST).read_text())
    words = len((ROOT / TEMPLATE).read_text().split())

    errors = (
        validate_manifest()
        + check_manifest_matches_folders(manifest_skills(manifest), folders)
        + check_skill_file_locations(tracked)
        + check_readme_tree(readme_tree_paths(readme), existing, folders)
        + check_word_count(readme, words)
    )
    for error in errors:
        print(error, file=sys.stderr)
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
