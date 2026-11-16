module Config where

import Data.Maybe (fromMaybe)
import Text.Read (readMaybe)

silentPort :: String -> Int
silentPort raw = port
  where
    -- Silent failure: bad input becomes port 0
    port = fromMaybe 0 (readMaybe raw)

-- Explicit failure with a clear message
parsePort :: String -> Either String Int
parsePort raw = case readMaybe raw of
  Just p | p > 0 && p < 65536 -> Right p
  _                           -> Left ("invalid PORT: " <> show raw)
