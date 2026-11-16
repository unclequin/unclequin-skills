# Fragments: lean4

Code that `skills/unix-philosophy/references/languages/lean4.md` shows on purpose
in a form that can't be compiled, with the reason. `scripts/check-examples.py`
skips exactly these paragraphs; everything else the file shows is in the
tested sources in this folder.

The "before" definition has `...` for a body.

```lean
-- Hard to compose: only works with a file path
def countLinesInFile (path : System.FilePath) : IO Nat := ...
```
