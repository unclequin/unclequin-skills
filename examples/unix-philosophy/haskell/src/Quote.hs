module Quote where

-- | Version 1 of the quote request.
data QuoteV1 = QuoteV1 { sku :: String, quantity :: Int }

-- | Version 2 adds an optional coupon; 'upgrade' turns every QuoteV1 into a QuoteV2.
data QuoteV2 = QuoteV2 { request :: QuoteV1, coupon :: Maybe String }

upgrade :: QuoteV1 -> QuoteV2
upgrade q = QuoteV2 q Nothing

prices :: [(String, Int)]
prices = [("apple", 100), ("pear", 150)]

percentOff :: [(String, Int)]
percentOff = [("TENOFF", 10)]

lookupIn :: String -> [(String, Int)] -> String -> Either String Int
lookupIn what table key = maybe (Left ("unknown " <> what <> ": " <> key)) Right (lookup key table)

quoteV1 :: QuoteV1 -> Either String Int
quoteV1 (QuoteV1 s n) = (* n) <$> lookupIn "sku" prices s

quoteV2 :: QuoteV2 -> Either String Int
quoteV2 (QuoteV2 (QuoteV1 s n) c) = do
  total <- (* n) <$> lookupIn "sku" prices s
  case c of
    Nothing -> pure total
    Just code -> do
      pct <- lookupIn "coupon" percentOff code
      pure (total - total * pct `div` 100)
