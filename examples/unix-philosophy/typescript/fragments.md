# Fragments: typescript

Code that `skills/unix-philosophy/references/languages/typescript.md` shows on purpose
in a form that can't be compiled, with the reason. `scripts/check-examples.py`
skips exactly these paragraphs; everything else the file shows is in the
tested sources in this folder.

The "before" signature has no body; the next paragraph redeclares `countLines`.

```ts
// Hard to compose: only works with a file path
async function countLines(path: string): Promise<number>
```

The "before" interface leaves out parameter and return types, which `tsc --strict` rejects.

```ts
// Over-engineered
interface IUserService { create(); get(); update(); delete(); list(); }
class UserServiceImpl implements IUserService { /* ... */ }
```

`withRetry` is shown with a comment for a body, which does not return. `examples.ts` has it with a real body.

```ts
async function withRetry<T>(policy: RetryPolicy, fn: () => Promise<T>): Promise<T> { /* mechanism */ }
```
