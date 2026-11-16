module Main (main) where

import Config (parsePort)
import System.Environment (getEnv)
import System.Exit (die)

run :: Int -> IO ()
run port = putStrLn ("listening on " <> show port)

main :: IO ()
main = do
  raw  <- getEnv "PORT"                 -- throws if missing: fail fast
  port <- either die pure (parsePort raw)
  run port
