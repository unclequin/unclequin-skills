-- The markdown shows the Arbitrary instances next to the properties, which
-- makes them orphans here, where the types live in another module.
{-# OPTIONS_GHC -Wno-orphans #-}

module Main (main) where

import Orders
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
