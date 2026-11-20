import Std.Data.String.ToNat

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

-- Before: three flags and two optional fields allow 2³ combinations of flags,
-- each with or without an amount and a tracking number. Four are legal.
structure OrderRecord where
  paid : Bool
  shipped : Bool
  cancelled : Bool
  amount : Option Nat
  tracking : Option String

/-- An amount in integer cents, greater than zero. -/
abbrev Amount := { n : Nat // n > 0 }

/-- Parses raw input at the boundary; the core takes only `Amount`. -/
def parseAmount (raw : String) : Except String Amount :=
  match raw.toNat? with
  | some n =>
    if h : raw.all Char.isDigit ∧ n > 0 then .ok ⟨n, h.2⟩
    else .error s!"invalid amount: {raw.quote}"
  | none => .error s!"invalid amount: {raw.quote}"

/-- `parseAmount` accepts exactly the strings of digits whose value is positive. -/
theorem parseAmount_ok_iff (raw : String) :
    (parseAmount raw).toBool = true ↔
      raw.all Char.isDigit = true ∧ ∃ n, raw.toNat? = some n ∧ n > 0 := by
  unfold parseAmount
  split
  · rename_i n hn
    split
    · rename_i h
      exact ⟨fun _ => ⟨h.1, n, hn, h.2⟩, fun _ => rfl⟩
    · rename_i h
      refine ⟨(nomatch ·), ?_⟩
      rintro ⟨digits, m, hm, pos⟩
      rw [hn] at hm
      cases hm
      exact absurd ⟨digits, pos⟩ h
  · rename_i hn
    refine ⟨(nomatch ·), ?_⟩
    rintro ⟨_, m, hm, _⟩
    rw [hn] at hm
    cases hm

/-- Every positive whole number of cents parses to itself. -/
theorem parseAmount_repr (n : Nat) (h : n > 0) : parseAmount (Nat.repr n) = .ok ⟨n, h⟩ := by
  have digits : (Nat.repr n).all Char.isDigit = true := by
    simpa [String.all_bool_eq, Nat.toList_repr] using
      fun c hc => Nat.isDigit_of_mem_toDigits (by omega) (by omega) hc
  simp [parseAmount, digits, Nat.toNat?_repr, h]

/-- An order indexed by its state: each constructor holds only its own data. -/
inductive OrderIn : State → Type where
  | draft (id : String) : OrderIn .draft
  | paid (id : String) (amount : Amount) : OrderIn .paid
  | shipped (id : String) (amount : Amount) (tracking : String) : OrderIn .shipped
  | cancelled (id : String) : OrderIn .cancelled

def OrderIn.id : OrderIn s → String
  | .draft id | .paid id _ | .shipped id _ _ | .cancelled id => id

/-- The amount to refund on cancellation: only money that was taken. -/
def refundDue : OrderIn s → Nat
  | .draft _ | .cancelled _ => 0
  | .paid _ amount | .shipped _ amount _ => amount.val

def allEvents : List Event := [.pay, .ship, .cancel]

/-- The messages a state accepts, read from the transition table. -/
def accepts (s : State) : List Event :=
  allEvents.filter fun e => (transition s e).isSome

-- Typestate: each operation takes only the state that accepts it.
def pay : OrderIn .draft → Amount → OrderIn .paid
  | .draft id, amount => .paid id amount

def ship : OrderIn .paid → String → OrderIn .shipped
  | .paid id amount, tracking => .shipped id amount tracking

/-- Cancel asks the table itself: `decide` proves the move is in it, or the call fails. -/
def cancel (o : OrderIn s) (_ : transition s .cancel = some .cancelled := by decide) :
    OrderIn .cancelled :=
  .cancelled o.id

theorem allEvents_complete (e : Event) : e ∈ allEvents := by
  cases e <;> decide

/-- A state accepts exactly the events `step` allows. -/
theorem accepts_iff_step (s : State) (e : Event) :
    e ∈ accepts s ↔ (step s e).toBool = true := by
  cases s <;> cases e <;> decide

/-- Terminal states accept nothing. -/
theorem accepts_terminal : accepts .shipped = [] ∧ accepts .cancelled = [] := by
  decide

#guard refundDue (ship (pay (.draft "o1") ⟨500, by decide⟩) "T1") == 500
#guard refundDue (cancel (pay (.draft "o1") ⟨500, by decide⟩)) == 0

-- A draft can't be shipped, and a shipped order can't be cancelled.
#guard_msgs (drop info) in
#check_failure ship (.draft "o1") "T1"
#guard_msgs (drop info) in
#check_failure cancel (.shipped "o1" ⟨500, by decide⟩ "T1")
