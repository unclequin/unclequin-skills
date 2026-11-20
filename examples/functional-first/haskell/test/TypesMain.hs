module Main (main) where

import Orders (step)
import Types (Draft (..), Order (..), accepts, cents, parseAmount, pay, refundDue, ship)
import Control.Monad (unless)
import Data.Char (isDigit)
import Data.Either (isRight)
import Data.Int (Int64)
import System.Exit (exitFailure)
import Test.QuickCheck

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

-- | The typestate operations chain: a paid draft can be shipped.
prop_paidDraftShips :: Bool
prop_paidDraftShips =
  fmap (\a -> refundDue (OrderShipped (ship (pay (Draft "o1") a) "T1"))) (parseAmount "500") == Right 500

-- quickCheck only prints a failure. Exit non-zero so the test run fails too.
main :: IO ()
main = do
  results <- mapM quickCheckResult
    [ property prop_acceptsMatchesStep
    , property prop_parseAcceptsPositiveWholeCents
    , property prop_parseKeepsEveryAmount
    , property prop_paidDraftShips
    ]
  unless (all isSuccess results) exitFailure
