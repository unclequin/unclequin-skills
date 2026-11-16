-- | The code shown in skills/functional-first/references/languages/haskell.md.
-- scripts/check-examples.py checks that the two stay the same.
module Orders where

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

-- | Spec: twelve passes, one per month.
revenueByMonthSpec :: Int -> [Order] -> [Int64]
revenueByMonthSpec year orders = [monthlyRevenue (YearMonth year m) orders | m <- [1 .. 12]]

-- | Derived from 'revenueByMonthSpec' by grouping instead of rescanning.
revenueByMonth :: Int -> [Order] -> [Int64]
revenueByMonth year orders =
  elems (accumArray (+) 0 (1, 12) [(ymMonth m, total o) | o <- orders, not (isRefunded o), Just m <- [paidIn o], ymYear m == year])

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
