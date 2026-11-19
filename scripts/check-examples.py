#!/usr/bin/env python3
"""Check that the code shown in the language reference files is tested code.

The rule: in every fenced code block of
skills/<skill>/references/languages/<lang>.md, each paragraph (a run of
lines with no blank line) appears, line for line, in a file under
examples/<skill>/<lang>/, and that folder passes its language's formatter,
linter, compiler and tests (COMMANDS).

A paragraph may be indented in the source file (a method shown on its own in
the markdown sits inside a class there); nothing else may differ.

A paragraph that is deliberately not real code (a signature with no body, a
`...` placeholder) is listed instead in examples/<skill>/<lang>/fragments.md,
inside a fenced block, next to the reason it can't be tested. A paragraph
listed there that the reference file no longer shows is an error.

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
SKILLS = ["functional-first", "unix-philosophy"]
FENCE = "```"
FRAGMENTS = "fragments.md"

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
        "cabal build all --enable-tests",
        "cabal test all --enable-tests --test-show-details=direct",
    ],
    "lean4": [
        "lake build",
    ],
    "elixir": [
        "mix deps.get",
        "mix format --check-formatted",
        "mix compile --warnings-as-errors",
        "mix test --warnings-as-errors",
    ],
    "c": [
        f"mkdir -p build && cc {C_FLAGS} -o build/orders orders.c",
        "./build/orders",
    ],
}


class Paragraph(NamedTuple):
    line: int  # 1-based line of its first line in the markdown file
    code: list[str]


def paragraphs(markdown: str) -> list[Paragraph]:
    """Every paragraph of every fenced block in a markdown text, in order."""
    found: list[Paragraph] = []
    in_block = False
    current: list[str] = []
    for number, line in enumerate(markdown.splitlines(), start=1):
        fence = line.startswith(FENCE)
        if in_block and not fence and line.strip():
            current.append(line)
            continue
        if current:
            found.append(Paragraph(number - len(current), current))
            current = []
        if fence:
            in_block = not in_block
    return found


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


def check_paragraphs(markdown_path: str, shown: list[Paragraph],
                     sources: dict[str, list[str]], fragments: list[Paragraph],
                     examples_dir: str) -> list[str]:
    """One error for each shown paragraph that is neither whole in one source
    file nor listed as a fragment, and one for each fragment no longer shown."""
    listed = [fragment.code for fragment in fragments]
    errors = []
    for paragraph in shown:
        if paragraph.code in listed:
            continue
        matched, path = max(
            ((lines_matched(paragraph.code, lines), path) for path, lines in sources.items()),
            default=(0, ""),
        )
        if matched == len(paragraph.code):
            continue
        if matched == 0:
            errors.append(
                f"{markdown_path}:{paragraph.line}: the code starting "
                f"`{paragraph.code[0].strip()}` is not in any file under {examples_dir}/ "
                f"(if it can't compile on purpose, list it in {examples_dir}/{FRAGMENTS})"
            )
            continue
        errors.append(
            f"{markdown_path}:{paragraph.line + matched}: `{paragraph.code[matched].strip()}` "
            f"differs from {path}, which matches the {matched} lines before it"
        )
    used = [paragraph.code for paragraph in shown]
    return errors + [
        f"{examples_dir}/{FRAGMENTS}:{fragment.line}: lists `{fragment.code[0].strip()}`, "
        f"which {markdown_path} no longer shows"
        for fragment in fragments
        if fragment.code not in used
    ]


def check_known_languages(asked: list[str], documented: set[str]) -> list[str]:
    known = documented & set(COMMANDS)
    return [
        f"{lang}: not a checked language (choose from {', '.join(sorted(known))})"
        for lang in asked
        if lang not in known
    ] + [
        f"{lang}: a reference file exists, but scripts/check-examples.py has no "
        f"COMMANDS entry for it"
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


def check_language(skill: str, lang: str) -> list[str]:
    markdown_path = f"skills/{skill}/references/languages/{lang}.md"
    examples_dir = f"examples/{skill}/{lang}"
    if not (ROOT / examples_dir).is_dir():
        return [f"{markdown_path}: there is no {examples_dir}/ holding its tested sources"]
    sources = read_sources(examples_dir)
    # The fragments list is prose, not a tested source.
    fragments = sources.pop(f"{examples_dir}/{FRAGMENTS}", [])
    return (
        check_paragraphs(
            markdown_path, paragraphs((ROOT / markdown_path).read_text()), sources,
            paragraphs("\n".join(fragments)), examples_dir,
        )
        + run_commands(lang, examples_dir, markdown_path)
    )


def main(asked: list[str]) -> int:
    documented = {
        skill: {p.stem for p in (ROOT / f"skills/{skill}/references/languages").glob("*.md")}
        for skill in SKILLS
    }
    every = set().union(*documented.values())
    errors = check_known_languages(asked, every)
    if not errors:
        for lang in asked or sorted(every):
            for skill in SKILLS:
                if lang in documented[skill]:
                    errors += check_language(skill, lang)
    for error in errors:
        print(error, file=sys.stderr)
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
