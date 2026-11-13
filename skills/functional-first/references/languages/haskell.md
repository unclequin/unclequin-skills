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

## Check: properties

With QuickCheck:

```haskell
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

main :: IO ()
main = do
  quickCheck prop_derivedEqualsSpec
  quickCheck prop_stepFollowsTable
```

`hedgehog` is the alternative, with generators as values and shrinking built in. Without either, an `iterate`-based seeded generator in a test executable works, without shrinking.

## Tooling

- Measure before deriving: `criterion` or `tasty-bench` for benchmarks, and `+RTS -s` and `-prof` for allocation and time profiles. Space leaks show up as a high "bytes maximum residency".
- `-Wall` on every build. `ormolu` or `fourmolu` for formatting, and `hlint` for suggestions.
