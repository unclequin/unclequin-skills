# Composable: works with open files, io.StringIO, sys.stdin, generators
from collections.abc import Iterable


def count_lines(lines: Iterable[str]) -> int:
    return sum(1 for _ in lines)
