# Haskell: Functional First

Haskell is where the composed spec is native: the sentence becomes a composition of `filter`, `map`, and `sum`, often in one line. Exhaustive pattern matching makes the transition table a function, and `foldM` is replay. The derivation risks are laziness (space leaks from lazy accumulators) and the cost of lists as a data structure.

## Compose: a composition of named predicates

```haskell
import Control.Monad (foldM)
import Data.Array (accumArray, elems)
import Data.Int (Int64)

data YearMonth = YearMonth { ymYear :: Int, ymMonth :: Int } -- month 1-12
  deriving (Eq, Show)

data Order = Order
  { orderId  :: String
  , total    :: Int64 -- cents
  , paidIn   :: Maybe YearMonth
  , refunded :: Bool
  } deriving (Show)

isPaidIn :: YearMonth -> Order -> Bool
isPaidIn m o = paidIn o == Just m

isRefunded :: Order -> Bool
isRefunded = refunded

-- | Revenue for a month is the sum of the totals of orders paid in that
-- month, except refunded ones. A refund at any time excludes the order.
monthlyRevenue :: YearMonth -> [Order] -> Int64
monthlyRevenue m = sum . map total . filter (not . isRefunded) . filter (isPaidIn m)
```

Read right to left, this is the set expression `Σ total over PaidIn(m) \ Refunded`. Put the month first so `monthlyRevenue m` is itself a reusable function of the orders.

## Derive: group instead of rescanning

```haskell
-- | Spec: twelve passes, one per month.
revenueByMonthSpec :: Int -> [Order] -> [Int64]
revenueByMonthSpec year orders = [monthlyRevenue (YearMonth year m) orders | m <- [1 .. 12]]

-- | Derived from 'revenueByMonthSpec' by grouping instead of rescanning.
revenueByMonth :: Int -> [Order] -> [Int64]
revenueByMonth year orders =
  elems (accumArray (+) 0 (1, 12) [(ymMonth m, total o) | o <- orders, not (isRefunded o), Just m <- [paidIn o], ymYear m == year])
```

`accumArray` (from `Data.Array`) groups in one pass. For an open set of keys, use `Data.Map.Strict.fromListWith (+)`. Use the strict variants: a lazy `Map` or a `foldl` accumulator builds a chain of unevaluated thunks, which is the classic Haskell space leak. Accumulate with `foldl'`, never `foldl`.

GHC's list fusion often removes the intermediate lists in `sum . map f . filter p`, so measure before hand-writing a loop.

## State machine: pattern matching as the table

```haskell
data State = Draft | Paid | Shipped | Cancelled
  deriving (Eq, Show, Enum, Bounded)

data Event = Pay | Ship | Cancel
  deriving (Eq, Show, Enum, Bounded)

-- | The whole lifecycle. A pair that isn't here is illegal.
transition :: State -> Event -> Maybe State
transition Draft Pay    = Just Paid
transition Draft Cancel = Just Cancelled
transition Paid  Ship   = Just Shipped
transition Paid  Cancel = Just Cancelled
transition _     _      = Nothing

data IllegalTransition = IllegalTransition State Event
  deriving (Eq, Show)

step :: State -> Event -> Either IllegalTransition State
step s e = maybe (Left (IllegalTransition s e)) Right (transition s e)

-- | Folds 'step' over events and stops at the first illegal one.
replay :: State -> [Event] -> Either IllegalTransition State
replay = foldM step
```

`foldM` in the `Either` monad stops at the first `Left`. That's the whole "stop at the first illegal event" rule in one word. Deriving `Enum` and `Bounded` gives `[minBound .. maxBound]` as the list of all states and events, for tests and for reachability checks. When states carry data, give the constructors fields (`Issued Int`), and keep `transition` as the readable table of which moves are legal.

## Types: sets of values, sets of messages

```haskell
-- Before: three flags and two optional fields allow 2³ combinations of flags,
-- each with or without an amount and a tracking number. Four are legal.
data OrderRecord = OrderRecord
  { paid      :: Bool
  , shipped   :: Bool
  , cancelled :: Bool
  , amount    :: Maybe Int64
  , tracking  :: Maybe String
  }
```

```haskell
-- | An amount in integer cents, greater than zero. Only 'parseAmount' makes one.
newtype Amount = Amount Int64
  deriving (Eq, Show)

cents :: Amount -> Int64
cents (Amount n) = n

-- | Parses raw input at the boundary; the core takes only 'Amount'.
parseAmount :: String -> Either String Amount
parseAmount raw = case readMaybe raw :: Maybe Integer of
  Just n | all isDigit raw, n > 0, n <= toInteger (maxBound :: Int64) -> Right (Amount (fromInteger n))
  _ -> Left ("invalid amount: " ++ show raw)
```

The module's export list names `Amount` without `(..)`, so other modules can't see its data constructor: they can't build one, pattern-match it open, or `coerce` an `Int64` into one. `parseAmount` is the only way in. Inside the module nothing stops you, so keep the module small. Parse through `Integer` and check the bound: `read` at `Int64` wraps on overflow without complaint.

```haskell
-- After: one type per state, each holding only its own data.
newtype Draft = Draft String                  -- id
data Paid = Paid String Amount                -- id, amount
data Shipped = Shipped String Amount String   -- id, amount, tracking
newtype Cancelled = Cancelled String          -- id

data Order
  = OrderDraft Draft
  | OrderPaid Paid
  | OrderShipped Shipped
  | OrderCancelled Cancelled

-- | The amount to refund on cancellation: only money that was taken.
refundDue :: Order -> Int64
refundDue (OrderDraft _)                 = 0
refundDue (OrderCancelled _)             = 0
refundDue (OrderPaid (Paid _ a))         = cents a
refundDue (OrderShipped (Shipped _ a _)) = cents a
```

`-Wall` includes `-Wincomplete-patterns`, and `-Werror` makes it an error, so adding a fifth state fails the build at every function that doesn't handle it. A catch-all `_` clause switches that check off for the function, so leave it out of decisions over domain types.

```haskell
-- | The messages a state accepts, read from the transition table.
accepts :: State -> [Event]
accepts s = [e | e <- [minBound .. maxBound], isJust (transition s e)]

-- Typestate: each operation takes only the states that accept it.
pay :: Draft -> Amount -> Paid
pay (Draft i) = Paid i

ship :: Paid -> String -> Shipped
ship (Paid i a) = Shipped i a

-- | The states that accept cancel. A class is a set of types.
class Cancellable s where
  cancel :: s -> Cancelled

instance Cancellable Draft where
  cancel (Draft i) = Cancelled i

instance Cancellable Paid where
  cancel (Paid i _) = Cancelled i
```

`Event` is the set of messages the lifecycle understands, and `accepts` reads one state's subset from `transition` instead of keeping a second list. The typed operations make the same table a compile-time check: `ship (Draft "o1") "T1"` is a type error, and `cancel` exists for exactly the types with an instance. Events that arrive as data, from a queue or a database, still go through `step`. A GADT indexed by `State` (with `DataKinds`) does the same in one type, at the cost of two extensions; one type per state is enough here.

## Check: properties

With QuickCheck:

```haskell
import Control.Monad (unless)
import System.Exit (exitFailure)
import Test.QuickCheck

instance Arbitrary YearMonth where
  arbitrary = YearMonth <$> elements [2024, 2025] <*> choose (1, 12)

instance Arbitrary Order where
  arbitrary = Order <$> arbitrary <*> choose (0, 1000) <*> arbitrary <*> arbitrary

instance Arbitrary Event where
  arbitrary = arbitraryBoundedEnum

prop_derivedEqualsSpec :: [Order] -> Bool
prop_derivedEqualsSpec orders = revenueByMonth 2024 orders == revenueByMonthSpec 2024 orders

prop_stepFollowsTable :: [Event] -> Bool
prop_stepFollowsTable = go Draft
  where
    go _ [] = True
    go s (e : es) = case step s e of
      Right s' -> transition s e == Just s' && go s' es
      Left err -> err == IllegalTransition s e && transition s e == Nothing && go s es

-- quickCheck only prints a failure. Exit non-zero so the test run fails too.
main :: IO ()
main = do
  results <- mapM quickCheckResult [property prop_derivedEqualsSpec, property prop_stepFollowsTable]
  unless (all isSuccess results) exitFailure
```

```haskell
prop_acceptsMatchesStep :: Bool
prop_acceptsMatchesStep =
  and [accepts s == [e | e <- [minBound .. maxBound], isRight (step s e)] | s <- [minBound .. maxBound]]

-- | Mostly digit strings, so the interesting cases come up often.
rawAmount :: Gen String
rawAmount = oneof [arbitrary, listOf (elements "0123456789+- ")]

prop_parseAcceptsPositiveWholeCents :: Property
prop_parseAcceptsPositiveWholeCents = forAll rawAmount $ \raw ->
  let n = read raw :: Integer
      valid = not (null raw) && all isDigit raw && n > 0 && n <= toInteger (maxBound :: Int64)
   in isRight (parseAmount raw) == valid

prop_parseKeepsEveryAmount :: Property
prop_parseKeepsEveryAmount = forAll (choose (1, maxBound)) $ \n ->
  fmap cents (parseAmount (show n)) == Right (n :: Int64)
```

The first property is a plain `Bool`: the states are few enough to check them all. There is no test that `ship (Draft "o1")` fails to compile: doing that needs `-fdefer-type-errors` and an extra package such as `should-not-typecheck`, so rely on the build itself.

`hedgehog` is the alternative, with generators as values and shrinking built in. Without either, an `iterate`-based seeded generator in a test executable works, without shrinking.

## Tooling

- Measure before deriving: `criterion` or `tasty-bench` for benchmarks, and `+RTS -s` and `-prof` for allocation and time profiles. Space leaks show up as a high "bytes maximum residency".
- `-Wall` on every build. `ormolu` or `fourmolu` for formatting, and `hlint` for suggestions.
