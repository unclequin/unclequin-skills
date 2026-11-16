#!/usr/bin/env python3
"""Check that the code shown in the language reference files is tested code.

The rule: every fenced code block in
skills/functional-first/references/languages/<lang>.md appears, line for
line, in a file under examples/functional-first/<lang>/, and that folder
passes its language's formatter, linter, compiler and tests (COMMANDS).

A block may be indented in the source file (a method shown on its own in the
markdown sits inside a class there); nothing else may differ. A block that
is deliberately not real code is skipped when the line above its opening
fence starts with `<!-- example: fragment`.

Usage: scripts/check-examples.py [lang ...]   (no arguments: every language)

Each check is a pure function from values to a list of error strings.
main() does all the reading and runs the commands.
Silent on success; errors go to stderr and the exit code is 1.
"""

import subprocess
import sys
from pathlib import Path
from typing import NamedTuple

ROOT = Path(__file__).resolve().parent.parent
REFERENCES = "skills/functional-first/references/languages"
EXAMPLES = "examples/functional-first"
FENCE = "```"
FRAGMENT_MARKER = "<!-- example: fragment"

C_FLAGS = "-std=c17 -Wall -Wextra -Wpedantic -Werror -fsanitize=address,undefined -g"

# What "tested" means for each language: shell commands run in its examples
# folder, in order, stopping at the first that fails.
COMMANDS: dict[str, list[str]] = {
    "go": [
        # gofmt -l exits 0 even when files need formatting, so fail on any output.
        "gofmt -l . | (! grep .)",
        "go vet ./...",
        "go test ./...",
    ],
    "typescript": [
        "npm ci --silent",
        "npx tsc",
        'node --test "*.test.ts"',
    ],
    "python": [
        "python3 -m ruff check .",
        "python3 -m mypy .",
        "python3 -m pytest -q",
    ],
    "java": [
        "mvn --batch-mode --quiet verify",
    ],
    "rust": [
        "cargo fmt --check",
        "cargo clippy --all-targets -- -D warnings",
        "cargo test",
    ],
    "haskell": [
        "cabal build all",
        # The main shown in haskell.md calls quickCheck, which exits 0 even
        # when a property fails, so fail on the failure text instead.
        "cabal test all --test-show-details=direct | (! grep -A8 'Failed!')",
    ],
    "lean4": [
        "lake build",
    ],
    "c": [
        f"mkdir -p build && cc {C_FLAGS} -o build/orders orders.c",
        "./build/orders",
    ],
}


class Block(NamedTuple):
    line: int  # 1-based line of the opening fence in the markdown file
    tag: str  # the fence's language tag, "" if none
    code: list[str]
    fragment: bool


def fenced_blocks(markdown: str) -> list[Block]:
    """Every fenced block in a markdown text, in order."""
    lines = markdown.splitlines()
    blocks: list[Block] = []
    opened: int | None = None
    for i, line in enumerate(lines):
        if not line.startswith(FENCE):
            continue
        if opened is None:
            opened = i
            continue
        blocks.append(Block(
            line=opened + 1,
            tag=lines[opened][len(FENCE):].strip(),
            code=lines[opened + 1:i],
            fragment=opened > 0 and lines[opened - 1].startswith(FRAGMENT_MARKER),
        ))
        opened = None
    return blocks


def indent_of(line: str) -> str:
    return line[:len(line) - len(line.lstrip())]


def lines_matched_at(code: list[str], source: list[str], start: int) -> int:
    """How many leading lines of code equal source from start on, when the
    source may carry one extra indent, the same on every line."""
    if not source[start].endswith(code[0]):
        return 0
    indent = source[start][:len(source[start]) - len(code[0])]
    if indent.strip():
        return 0
    matched = 0
    for shown, real in zip(code, source[start:]):
        same = real == indent + shown or (not shown.strip() and not real.strip())
        if not same:
            break
        matched += 1
    return matched


def lines_matched(code: list[str], source: list[str]) -> int:
    """The longest run of leading lines of code found anywhere in source."""
    return max(
        (lines_matched_at(code, source, start) for start in range(len(source))),
        default=0,
    )


def check_blocks(markdown_path: str, blocks: list[Block], sources: dict[str, list[str]],
                 examples_dir: str) -> list[str]:
    """One error for each block that is not, whole, in any one source file."""
    errors = []
    for block in blocks:
        if block.fragment:
            continue
        where = f"{markdown_path}:{block.line}: the {block.tag or 'untagged'} block"
        if not block.code:
            errors.append(f"{where} is empty")
            continue
        matched, path = max(
            ((lines_matched(block.code, lines), path) for path, lines in sources.items()),
            default=(0, ""),
        )
        if matched == len(block.code):
            continue
        if matched == 0:
            errors.append(
                f"{where} starting `{block.code[0].strip()}` is not in any file "
                f"under {examples_dir}/"
            )
            continue
        errors.append(
            f"{where} differs from {path} at line {block.line + 1 + matched}: "
            f"`{block.code[matched].strip()}`"
        )
    return errors


def check_known_languages(asked: list[str], documented: set[str]) -> list[str]:
    known = documented & set(COMMANDS)
    return [
        f"{lang}: not a checked language (choose from {', '.join(sorted(known))})"
        for lang in asked
        if lang not in known
    ] + [
        f"{REFERENCES}/{lang}.md: scripts/check-examples.py has no COMMANDS entry for {lang}"
        for lang in sorted(documented - set(COMMANDS))
    ]


def read_sources(examples_dir: str) -> dict[str, list[str]]:
    """Text files in the folder, tracked or not yet, but not ignored ones
    (dependencies and build output)."""
    listed = subprocess.run(
        ["git", "ls-files", "--cached", "--others", "--exclude-standard", examples_dir],
        cwd=ROOT, capture_output=True, text=True, check=True,
    ).stdout.splitlines()
    sources = {}
    for path in listed:
        try:
            sources[path] = (ROOT / path).read_text().splitlines()
        except (UnicodeDecodeError, FileNotFoundError):
            # Not text, or deleted but still in the index: no block lives there.
            continue
    return sources


def run_commands(lang: str, examples_dir: str, markdown_path: str) -> list[str]:
    for command in COMMANDS[lang]:
        result = subprocess.run(
            command, shell=True, cwd=ROOT / examples_dir, capture_output=True, text=True,
        )
        if result.returncode != 0:
            output = (result.stdout + result.stderr).rstrip()
            return [
                f"{examples_dir}: `{command}` failed with exit code {result.returncode} "
                f"(this is the code shown in {markdown_path}):\n{output}"
            ]
    return []


def check_language(lang: str) -> list[str]:
    markdown_path = f"{REFERENCES}/{lang}.md"
    examples_dir = f"{EXAMPLES}/{lang}"
    if not (ROOT / examples_dir).is_dir():
        return [f"{markdown_path}: there is no {examples_dir}/ holding its tested sources"]
    blocks = fenced_blocks((ROOT / markdown_path).read_text())
    return (
        check_blocks(markdown_path, blocks, read_sources(examples_dir), examples_dir)
        + run_commands(lang, examples_dir, markdown_path)
    )


def main(asked: list[str]) -> int:
    documented = {p.stem for p in (ROOT / REFERENCES).glob("*.md")}
    errors = check_known_languages(asked, documented)
    if not errors:
        for lang in asked or sorted(documented):
            errors += check_language(lang)
    for error in errors:
        print(error, file=sys.stderr)
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
