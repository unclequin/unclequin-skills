# Fragments: go

Code that `skills/unix-philosophy/references/languages/go.md` shows on purpose
in a form that can't be compiled, with the reason. `scripts/check-examples.py`
skips exactly these paragraphs; everything else the file shows is in the
tested sources in this folder.

The "before" signature has no body; the next paragraph redeclares `CountLines`.

```go
// Hard to compose: only works with files on disk
func CountLines(path string) (int, error)
```

The "before" interface uses `...` for its parameters.

```go
// Over-engineered: producer-side interface mirroring every method
type UserService interface { Create(...); Get(...); Update(...); Delete(...); List(...) }
```

`Do` is shown with a comment for a body, which does not return. `examples.go` has it with a real body.

```go
func Do(ctx context.Context, p RetryPolicy, fn func() error) error { /* mechanism only */ }
```
