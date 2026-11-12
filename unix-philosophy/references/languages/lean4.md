# Lean 4 Idioms for the Unix Philosophy

Lean 4 is both a functional programming language and a theorem prover, so these rules apply to programs *and* proofs. Small lemmas that compose are the proof-level version of small programs joined by pipes. Follow the Lean core and Mathlib style and naming conventions.

## Modularity: small definitions, small lemmas

- One concept per file; group related definitions with `namespace` and `section`.
- Break a long proof into named helper lemmas, each stating one fact. A lemma you can name clearly is a lemma others can reuse.
- Keep executable definitions and their correctness proofs close but separate (see Separation).

## Clarity: proofs a reader can follow

- Prefer structured proofs: `have h : ... := ...` with descriptive hypothesis names, `calc` for chains of equalities, `induction ... with` with named cases.
- Use `simp only [...]` (find the lemma list with `simp?`) for non-terminal steps, so proofs don't silently break when the simp set changes. A bare `simp` is fine when it closes the goal.
- Avoid long opaque tactic chains that nobody can repair later.

## Composition: accept general types and streams

```lean
-- Hard to compose: only works with a file path
def countLinesInFile (path : System.FilePath) : IO Nat := ...

-- Composable: works with stdin, files, or any IO.FS.Stream
partial def countLines (s : IO.FS.Stream) (acc : Nat := 0) : IO Nat := do
  let line ← s.getLine
  if line.isEmpty then
    return acc
  else
    countLines s (acc + 1)

-- countLines (← IO.getStdin)
-- countLines (IO.FS.Stream.ofHandle (← IO.FS.Handle.mk path .read))
```

Prefer pure functions over `List` / `Array` for logic and keep `IO` at the edges. Use standard type classes (`Functor`, `Monad`, `ForIn`, `ToString`) so your types work with existing tools.

## Separation: specification apart from implementation

The Lean version of "policy vs. mechanism": write a simple, obviously correct specification, write an efficient implementation, and prove they agree. Each can change without hiding a bug in the other.

```lean
-- Specification: simple and obviously correct
def sumSpec : List Nat → Nat
  | [] => 0
  | x :: xs => x + sumSpec xs

-- Implementation: tail-recursive and efficient
def sumFast (xs : List Nat) : Nat := xs.foldl (· + ·) 0

theorem foldl_add_eq (xs : List Nat) (acc : Nat) :
    xs.foldl (· + ·) acc = acc + sumSpec xs := by
  induction xs generalizing acc with
  | nil => simp [sumSpec]
  | cons x xs ih => simp [sumSpec, ih, Nat.add_assoc]

theorem sumFast_eq_sumSpec (xs : List Nat) : sumFast xs = sumSpec xs := by
  simp [sumFast, foldl_add_eq]
```

For configurable behavior in programs, pass policy as a `structure` value rather than hardcoding it.

## Simplicity

- Use a plain `structure` or function instead of a `class` when instance inference isn't needed.
- Don't build deep type class hierarchies or heavy dependent types until a real use requires them.
- Prefer structural recursion; reach for well-founded recursion with `termination_by` only when needed, and `partial` only for code you won't reason about.

## Transparency and Repair: no hidden holes, explicit failure

`sorry` is the ultimate silent failure: it makes anything "proved". Never commit it. Check what a theorem depends on with `#print axioms`.

```lean
-- Silent failure: bad input becomes port 0
def parsePort (s : String) : Nat := s.toNat?.getD 0

-- Explicit failure the caller must handle
def parsePort (s : String) : Except String Nat :=
  match s.toNat? with
  | some n => if n < 65536 then .ok n else .error s!"port out of range: {n}"
  | none => .error s!"invalid port: {s.quote}"
```

- Use `Option` and `Except` for expected failures; in `IO`, `throw (IO.userError s!"...")` with context.
- Red flags: `sorry`, `panic!`, bang operators (`get!`, `xs[i]!`, `.get!`) on data that may be missing, `partial def` hiding non-termination in code that should be total.
- Prefer `xs[i]?` / `getD`, or carry the bounds proof (`xs[i]'h`) so the type system rules out the failure.
- Derive `Repr` for data types so `#eval` shows readable values while debugging.

## Representation: inductive types and structures

```lean
inductive Zone where
  | bkk | central | north | other
  deriving Repr, DecidableEq

def Zone.fee : Zone → Nat
  | .bkk => 40
  | .central => 60
  | .north => 80
  | .other => 100
```

Lean checks the match is exhaustive. Use subtypes (`{ n : Nat // n < 65536 }`) and structures with proof fields to make invalid states unrepresentable.

## Least Surprise: Lean conventions

- `UpperCamelCase` for types, structures, and inductives; `lowerCamelCase` for definitions; `snake_case` for theorem names, which describe the statement (`add_comm`, `foldl_add_eq`).
- Put functions in the type's namespace (`Zone.fee`) so dot notation (`z.fee`) works.
- Mark lemmas `@[simp]` only when they always rewrite toward a simpler form; a bad simp lemma surprises every later proof.

## Silence

Remove debugging commands (`#eval`, `#check`, `#print`, `trace` options) before committing, and keep the build free of linter warnings so real warnings stand out. Programs print results to stdout, diagnostics to stderr, and return a non-zero `UInt32` from `main` on failure.

## Generation

Use `deriving` handlers (`Repr`, `BEq`, `DecidableEq`, `Hashable`, `Inhabited`, `Ord`) instead of hand-written instances. Write a `macro` or a small tactic when the same proof pattern repeats; Lean's metaprogramming is the "programs that write programs" rule built in.

## Optimization

Measure first with `set_option profiler true` for elaboration and proof time, and `timeit` for runtime. Common wins: `Array` instead of `List` for indexed or large data, tail recursion, `@[inline]` / `@[specialize]` on small hot functions. To swap in a faster implementation, keep the simple definition as the spec and prove the replacement equal (`@[csimp]`), rather than trusting `@[implemented_by]` blindly.

## Extensibility

Give `structure` fields default values so new fields don't break existing code, use type classes where users must add their own instances, and keep public lemma statements stable because downstream proofs depend on them.
