# Lean 4: Functional First

In Lean, the composed spec is an ordinary definition, and step 5 can be a proof instead of a test. Properties from the model become theorems that the kernel checks for all inputs. Small concrete checks run at compile time with `decide`. Derived code uses `Array` and `Id.run do` loops, which compile to in-place updates when the array isn't shared.

## Compose: a pipeline over a list

```lean
structure YearMonth where
  year : Nat
  month : Nat -- 1-12
  deriving DecidableEq, Repr

structure Order where
  id : String
  total : Nat -- cents
  paidIn : Option YearMonth
  refunded : Bool
  deriving Repr

def isPaidIn (m : YearMonth) (o : Order) : Bool := o.paidIn == some m

def isRefunded (o : Order) : Bool := o.refunded

/-- Revenue for a month is the sum of the totals of orders paid in that month,
except refunded ones. A refund at any time excludes the order. -/
def monthlyRevenue (m : YearMonth) (orders : List Order) : Nat :=
  ((orders.filter (isPaidIn m)).filter (fun o => !isRefunded o)).map (·.total) |>.sum
```

Keep predicates returning `Bool` so `List.filter` takes them directly and `decide` can evaluate them.

## Check: prove the model's laws

The set laws from `modeling.md` become theorems:

```lean
/-- Adding an unpaid order never changes revenue. -/
theorem monthlyRevenue_unpaid (m : YearMonth) (orders : List Order) (o : Order)
    (h : o.paidIn = none) : monthlyRevenue m (o :: orders) = monthlyRevenue m orders := by
  simp [monthlyRevenue, isPaidIn, h]

/-- Filtering never increases a sum. -/
theorem sum_filter_le (p : α → Bool) (f : α → Nat) (l : List α) :
    ((l.filter p).map f).sum ≤ (l.map f).sum := by
  induction l with
  | nil => simp
  | cons x xs ih => by_cases h : p x <;> simp [List.filter, h] <;> omega

/-- Revenue never exceeds the sum of all totals. -/
theorem monthlyRevenue_le (m : YearMonth) (orders : List Order) :
    monthlyRevenue m orders ≤ (orders.map (·.total)).sum :=
  Nat.le_trans (sum_filter_le _ _ _) (sum_filter_le _ _ _)
```

Prove the general law once (`sum_filter_le`, for any predicate), then apply it to each filter in the pipeline. That's the proof version of "one phrase, one function". A direct induction on `monthlyRevenue` gets stuck, because `simp` merges the two filters in the goal but not in the induction hypothesis.

## Derive: an Array loop, checked against the spec

```lean
/-- Spec: twelve passes, one per month. -/
def revenueByMonthSpec (year : Nat) (orders : List Order) : List Nat :=
  (List.range 12).map fun i => monthlyRevenue ⟨year, i + 1⟩ orders

/-- Derived from `revenueByMonthSpec` by grouping instead of rescanning. -/
def revenueByMonth (year : Nat) (orders : List Order) : List Nat := Id.run do
  let mut out := Array.replicate 12 0
  for o in orders do
    if let some m := o.paidIn then
      if m.year == year && !isRefunded o && 1 ≤ m.month && m.month ≤ 12 then
        out := out.modify (m.month - 1) (· + o.total)
  return out.toList
```

The `1 ≤ m.month && m.month ≤ 12` guard is part of the derivation. `YearMonth` doesn't constrain the month, and the spec only ever asks about months 1 to 12, so the derived code must ignore other values the same way. Proving that the derived and spec versions are equal for all inputs takes a loop invariant and real effort. For everyday code, check examples at compile time, and use `plausible` for random inputs:

```lean
def sample : List Order :=
  [⟨"a", 100, some ⟨2024, 3⟩, false⟩, ⟨"b", 50, some ⟨2024, 3⟩, true⟩,
   ⟨"c", 70, some ⟨2024, 12⟩, false⟩, ⟨"d", 20, none, false⟩, ⟨"e", 5, some ⟨2025, 3⟩, false⟩]

example : revenueByMonth 2024 sample = revenueByMonthSpec 2024 sample := by decide
example : monthlyRevenue ⟨2024, 3⟩ sample = 100 := by decide
```

`decide` is checked by the kernel, so a wrong expected value fails the build. Prove the derived and spec versions equal when the code is security- or money-critical and the team has the time. That proof is the strongest form of the spec-equals-derived property.

## State machine: pattern matching as the table

```lean
inductive State where
  | draft | paid | shipped | cancelled
  deriving DecidableEq, Repr

inductive Event where
  | pay | ship | cancel
  deriving DecidableEq, Repr

/-- The whole lifecycle. A pair that isn't here is illegal. -/
def transition : State → Event → Option State
  | .draft, .pay    => some .paid
  | .draft, .cancel => some .cancelled
  | .paid,  .ship   => some .shipped
  | .paid,  .cancel => some .cancelled
  | _,      _       => none

def step (s : State) (e : Event) : Except String State :=
  match transition s e with
  | some next => .ok next
  | none => .error s!"cannot {repr e} an order that is {repr s}"

/-- Folds `step` over events and stops at the first illegal one. -/
def replay (start : State) (events : List Event) : Except String State :=
  events.foldlM step start

/-- Terminal states accept no event. -/
theorem terminal_absorbs (e : Event) :
    transition .shipped e = none ∧ transition .cancelled e = none := by
  cases e <;> simp [transition]

/-- Once a replay reaches a terminal state, any further event fails. -/
theorem shipped_then_any_fails (e : Event) (es : List Event) :
    (replay .shipped (e :: es)).toOption = none := by
  cases e <;> rfl
```

The state invariants from `modeling.md` are theorems here, proven by case analysis over every event, so no random testing is needed. When states carry data, give the constructors fields (`| issued (term : Nat)`) and prove the data invariants too, for example that a term never decreases.

## Tooling

- `lake build` checks every proof and every `decide` example. A failing law fails the build.
- `plausible` (`#test` or the `plausible` tactic) for random testing of a claim before you invest in proving it.
- For speed, measure with `timeit` in `IO`, and compile hot code rather than running it in the interpreter. Prefer `Array` over `List` in derived code.
