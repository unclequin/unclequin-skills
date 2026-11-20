/-! The code shown in skills/unix-philosophy/references/languages/lean4.md.
scripts/check-examples.py checks that the two stay the same. -/

-- Composable: works with stdin, files, or any IO.FS.Stream
partial def countLines (s : IO.FS.Stream) (acc : Nat := 0) : IO Nat := do
  let line ← s.getLine
  if line.isEmpty then
    return acc
  else
    countLines s (acc + 1)

-- countLines (← IO.getStdin)
-- countLines (IO.FS.Stream.ofHandle (← IO.FS.Handle.mk path .read))
def countStdinLines : IO Nat := do
  countLines (← IO.getStdin)

def countFileLines (path : System.FilePath) : IO Nat := do
  countLines (IO.FS.Stream.ofHandle (← IO.FS.Handle.mk path .read))

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

example : sumFast [1, 2, 3] = 6 := by decide

namespace Silent

-- Silent failure: bad input becomes port 0
def parsePort (s : String) : Nat := s.toNat?.getD 0

#guard parsePort "8080" == 8080
#guard parsePort "eighty" == 0

end Silent

namespace Explicit

-- Explicit failure the caller must handle
def parsePort (s : String) : Except String Nat :=
  match s.toNat? with
  | some n => if n < 65536 then .ok n else .error s!"port out of range: {n}"
  | none => .error s!"invalid port: {s.quote}"

#guard parsePort "8080" matches .ok 8080
#guard parsePort "65536" matches .error _
#guard parsePort "eighty" matches .error _

end Explicit

inductive Zone where
  | bkk | central | north | other
  deriving Repr, DecidableEq

def Zone.fee : Zone → Nat
  | .bkk => 40
  | .central => 60
  | .north => 80
  | .other => 100

example : [Zone.bkk, .central, .north, .other].map Zone.fee = [40, 60, 80, 100] := by decide

/-- Version 1 of the quote request. -/
structure QuoteV1 where
  sku : String
  quantity : Nat

/-- Version 2 adds a coupon that defaults to none, so every QuoteV1 is still a QuoteV2. -/
structure QuoteV2 extends QuoteV1 where
  coupon : Option String := none

instance : Coe QuoteV1 QuoteV2 := ⟨fun q => { toQuoteV1 := q }⟩

def prices : List (String × Nat) := [("apple", 100), ("pear", 150)]
def percentOff : List (String × Nat) := [("TENOFF", 10)]

def lookupIn (what : String) (table : List (String × Nat)) (key : String) : Except String Nat :=
  match table.lookup key with
  | some value => .ok value
  | none => .error s!"unknown {what}: {key}"

def quoteV1 (q : QuoteV1) : Except String Nat := do
  return (← lookupIn "sku" prices q.sku) * q.quantity

def quoteV2 (q : QuoteV2) : Except String Nat := do
  let total := (← lookupIn "sku" prices q.sku) * q.quantity
  match q.coupon with
  | none => return total
  | some code => return total - total * (← lookupIn "coupon" percentOff code) / 100

theorem quoteV2_answers_every_v1_request_the_same (q : QuoteV1) :
    quoteV2 q = quoteV1 q := rfl

#guard quoteV2 { sku := "pear", quantity := 3, coupon := some "TENOFF" } matches .ok 405
#guard quoteV2 { sku := "pear", quantity := 3, coupon := some "BOGUS" } matches .error _
