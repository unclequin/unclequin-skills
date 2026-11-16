# Fragments: rust

Code that `skills/unix-philosophy/references/languages/rust.md` shows on purpose
in a form that can't be compiled, with the reason. `scripts/check-examples.py`
skips exactly these paragraphs; everything else the file shows is in the
tested sources in this folder.

The "before" signature has no body; the next paragraph redeclares `count_lines`.

```rust
// Hard to compose: only works with files
fn count_lines(path: &Path) -> io::Result<usize>
```

`with_retry` is shown with a comment for a body, which does not return. `src/lib.rs` has it with a real body.

```rust
pub async fn with_retry<T, E, F, Fut>(policy: &RetryPolicy, f: F) -> Result<T, E>
where
    F: FnMut() -> Fut,
    Fut: Future<Output = Result<T, E>>,
{ /* mechanism only */ }
```
