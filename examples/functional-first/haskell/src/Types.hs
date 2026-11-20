-- | Types: sets of values, sets of messages. The code shown in the "Types"
-- section of skills/functional-first/references/languages/haskell.md.
module Types
  ( OrderRecord (..)
  , Amount
  , cents
  , parseAmount
  , Draft (..)
  , Paid (..)
  , Shipped (..)
  , Cancelled (..)
  , Order (..)
  , refundDue
  , accepts
  , pay
  , ship
  , Cancellable (..)
  ) where

import Data.Char (isDigit)
import Data.Int (Int64)
import Data.Maybe (isJust)
import Text.Read (readMaybe)
import Orders (Event, State, transition)

-- Before: three flags and two optional fields allow 2³ combinations of flags,
-- each with or without an amount and a tracking number. Four are legal.
data OrderRecord = OrderRecord
  { paid      :: Bool
  , shipped   :: Bool
  , cancelled :: Bool
  , amount    :: Maybe Int64
  , tracking  :: Maybe String
  }

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

-- | The messages a state accepts, read from the transition table.
accepts :: State -> [Event]
accepts s = [e | e <- [minBound .. maxBound], isJust (transition s e)]

-- Typestate: each operation takes only the states that accept it.
pay :: Draft -> Amount -> Paid
pay (Draft i) = Paid i

ship :: Paid -> String -> Shipped
ship (Paid i a) = Shipped i a

-- | The states that accept cancel. A class is a set of types.
-- Law: cancelling keeps the order's id.
class Cancellable s where
  cancel :: s -> Cancelled

instance Cancellable Draft where
  cancel (Draft i) = Cancelled i

instance Cancellable Paid where
  cancel (Paid i _) = Cancelled i
