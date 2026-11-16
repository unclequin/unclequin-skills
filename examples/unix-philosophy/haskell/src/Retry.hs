module Retry where

import Control.Concurrent (threadDelay)
import Control.Exception (SomeException, throwIO, try)

data RetryPolicy = RetryPolicy
  { maxAttempts   :: Int
  , backoffMicros :: Int
  }

withRetry :: RetryPolicy -> IO a -> IO a   -- mechanism only
withRetry policy action = go (maxAttempts policy)
  where
    go attemptsLeft = do
      result <- try action
      case result of
        Right value -> pure value
        Left err
          | attemptsLeft <= 1 -> throwIO (err :: SomeException)
          | otherwise -> threadDelay (backoffMicros policy) >> go (attemptsLeft - 1)

callPartner :: IO ()
callPartner = pure ()

retryPartner :: IO ()
retryPartner =
  -- caller chooses the policy
  withRetry (RetryPolicy 3 200000) callPartner
