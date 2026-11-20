module Main (main) where

import Config (parsePort, silentPort)
import Control.Exception (ErrorCall (..), throwIO, try)
import Control.Monad (unless)
import Data.Either (isLeft)
import Data.IORef (modifyIORef', newIORef, readIORef)
import Order (mkOrder, orderTotal)
import Quote (QuoteV1 (..), QuoteV2 (..), prices, quoteV1, quoteV2, upgrade)
import Retry (RetryPolicy (..), retryPartner, withRetry)
import System.Exit (exitFailure)
import Zone (zoneFee)

retryGivesUpAfterMaxAttempts :: IO Bool
retryGivesUpAfterMaxAttempts = do
  calls <- newIORef (0 :: Int)
  result <- try (withRetry (RetryPolicy 3 0) (modifyIORef' calls (+ 1) >> throwIO (ErrorCall "down")))
  count <- readIORef calls
  pure (result == (Left (ErrorCall "down") :: Either ErrorCall ()) && count == 3)

v2AnswersEveryV1RequestTheSame :: Bool
v2AnswersEveryV1RequestTheSame =
  and
    [ quoteV2 (upgrade q) == quoteV1 q
    | s <- map fst prices
    , n <- [1 .. 100]
    , let q = QuoteV1 s n
    ]

main :: IO ()
main = do
  retryPartner
  retried <- retryGivesUpAfterMaxAttempts
  let failed =
        [ name
        | (name, ok) <-
            [ ("mkOrder rejects an empty order", isLeft (mkOrder []))
            , ("mkOrder rejects a negative price", isLeft (mkOrder [10, -1]))
            , ("orderTotal sums the lines", fmap orderTotal (mkOrder [10, 5]) == Right 15)
            , ("withRetry gives up after maxAttempts", retried)
            , ("silentPort turns bad input into 0", silentPort "eighty" == 0)
            , ("parsePort accepts a port", parsePort "8080" == Right 8080)
            , ("parsePort rejects text", parsePort "eighty" == Left "invalid PORT: \"eighty\"")
            , ("parsePort rejects 0 and 65536", all (isLeft . parsePort) ["0", "65536"])
            , ("version 2 answers every version 1 request the same", v2AnswersEveryV1RequestTheSame)
            , ("a coupon takes 10 percent off", quoteV2 (QuoteV2 (QuoteV1 "pear" 3) (Just "TENOFF")) == Right 405)
            , ("an unknown coupon fails", quoteV2 (QuoteV2 (QuoteV1 "pear" 3) (Just "BOGUS")) == Left "unknown coupon: BOGUS")
            , ("every zone has its fee", map zoneFee [minBound .. maxBound] == [40, 60, 80, 100])
            ]
        , not ok
        ]
  unless (null failed) $ do
    mapM_ (putStrLn . ("FAILED: " <>)) failed
    exitFailure
