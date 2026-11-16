-- The code shown in skills/unix-philosophy/references/languages/haskell.md.
-- scripts/check-examples.py checks that the files in this folder and that
-- file stay the same.
module Order
  ( Order        -- type exported, constructor hidden
  , mkOrder      -- smart constructor validates input
  , orderTotal
  ) where

newtype Order = Order { orderLines :: [Int] }

mkOrder :: [Int] -> Either String Order
mkOrder prices
  | null prices = Left "an order needs at least one line"
  | any (< 0) prices = Left "a price can't be negative"
  | otherwise = Right (Order prices)

orderTotal :: Order -> Int
orderTotal = sum . orderLines
