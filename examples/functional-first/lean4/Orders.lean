/-! The code shown in skills/functional-first/references/languages/lean4.md.
scripts/check-examples.py checks that the two stay the same. -/

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

def sample : List Order :=
  [⟨"a", 100, some ⟨2024, 3⟩, false⟩, ⟨"b", 50, some ⟨2024, 3⟩, true⟩,
   ⟨"c", 70, some ⟨2024, 12⟩, false⟩, ⟨"d", 20, none, false⟩, ⟨"e", 5, some ⟨2025, 3⟩, false⟩]

example : revenueByMonth 2024 sample = revenueByMonthSpec 2024 sample := by decide
example : monthlyRevenue ⟨2024, 3⟩ sample = 100 := by decide

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
