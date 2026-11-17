#!/usr/bin/env python3
"""Check that every plugin whose files changed has a higher version.

Usage: scripts/check-versions.py <base-ref>

The rule: compared with <base-ref>, a plugin whose installed files changed
(anything under skills/<name>/ or plugins/<name>/) has a higher version in
the marketplace manifest, and no plugin's version goes down. Claude Code
only offers an update when the version changes, so a change without a bump
never reaches people who already installed the plugin.

check_bumps is pure; main() reads git. Silent on success; errors go to
stderr and the exit code is 1.
"""

import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MANIFEST = ".claude-plugin/marketplace.json"


def parse(version: str) -> tuple[int, ...]:
    return tuple(int(part) for part in version.split("."))


def plugin_files_changed(name: str, changed: list[str]) -> list[str]:
    """The changed files that are installed as part of plugin <name>."""
    return [p for p in changed if p.startswith((f"skills/{name}/", f"plugins/{name}/"))]


def check_bumps(changed: list[str], old: dict[str, str], new: dict[str, str]) -> list[str]:
    """old and new map plugin name to version; a plugin new in this change has no old entry."""
    errors = []
    for name, version in sorted(new.items()):
        if name not in old:
            continue
        before, after = parse(old[name]), parse(version)
        files = plugin_files_changed(name, changed)
        if after < before:
            errors.append(f"{MANIFEST}: plugin {name} goes down from {old[name]} to {version}")
        elif files and after == before:
            errors.append(
                f"{MANIFEST}: plugin {name} is still {version}, but its files changed "
                f"({', '.join(files[:3])}{', ...' if len(files) > 3 else ''}); raise its version"
            )
    return errors


def versions(manifest: dict) -> dict[str, str]:
    return {p["name"]: p.get("version", "0.0.0") for p in manifest["plugins"]}


def git(*args: str) -> subprocess.CompletedProcess:
    return subprocess.run(["git", *args], cwd=ROOT, capture_output=True, text=True)


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: scripts/check-versions.py <base-ref>", file=sys.stderr)
        return 2
    base = sys.argv[1]
    diff = git("diff", "--name-only", f"{base}...HEAD")
    if diff.returncode != 0:
        print(f"check-versions: git diff against {base} failed: {diff.stderr.strip()}", file=sys.stderr)
        return 1
    shown = git("show", f"{base}:{MANIFEST}")
    # A base with no manifest has no released plugins to compare against.
    old = versions(json.loads(shown.stdout)) if shown.returncode == 0 else {}
    new = versions(json.loads((ROOT / MANIFEST).read_text()))

    errors = check_bumps(diff.stdout.splitlines(), old, new)
    for error in errors:
        print(error, file=sys.stderr)
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
