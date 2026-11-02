# Haskell Idioms for the Unix Philosophy

Haskell's purity and function composition are the Unix pipe idea at the language level: small functions joined by `.` and `>>=`. The main risk is the opposite of Simplicity and Clarity: type-level machinery, deep monad transformer stacks, and point-free code nobody can read. Compile with `-Wall`, and use `hlint` and `fourmolu` or `ormolu`.

## Modularity: small modules with explicit export lists

Each module exports only what callers need. Hiding constructors lets the internal representation change without breaking callers.

```haskell
module Order
  ( Order        -- type exported, constructor hidden
  , mkOrder      -- smart constructor validates input
  , orderTotal
  ) where
```

## Composition: pure functions, IO at the edges

```haskell
-- Hard to compose: logic tied to a file
countLinesInFile :: FilePath -> IO Int

-- Composable: pure function over text; works with stdin, files, tests
countLines :: Text -> Int
countLines = length . T.lines

main :: IO ()
main = TIO.getContents >>= print . countLines
```

Accept the most general structure that works (`Foldable t => t a`, `Text`, streams from `conduit` or `streaming` for large inputs). Build pipelines from small functions.

## Separation: functional core, imperative shell

Business rules are pure functions; IO code only gathers inputs and acts on outputs. Pass policy as plain data.

```haskell
data RetryPolicy = RetryPolicy
  { maxAttempts   :: Int
  , backoffMicros :: Int
  }

withRetry :: RetryPolicy -> IO a -> IO a   -- mechanism only

-- caller chooses the policy
withRetry (RetryPolicy 3 200000) callPartner
```

## Simplicity: plain functions and records first

- Don't create a type class with one instance; use a function or a record of functions.
- Prefer `ReaderT Env IO` (or plain `IO` with explicit arguments) over deep mtl transformer stacks for application code.
- Reach for GADTs, type families, and heavy type-level programming only when a real problem demands them.
- Point-free style is fine when it reads clearly; name intermediate values when it doesn't (Clarity).

## Transparency and Repair: total functions, explicit failure

```haskell
-- Silent failure: bad input becomes port 0
port = fromMaybe 0 (readMaybe raw)

-- Explicit failure with a clear message
parsePort :: String -> Either String Int
parsePort raw = case readMaybe raw of
  Just p | p > 0 && p < 65536 -> Right p
  _                           -> Left ("invalid PORT: " <> show raw)

main :: IO ()
main = do
  raw  <- getEnv "PORT"                 -- throws if missing: fail fast
  port <- either die pure (parsePort raw)
  run port
```

- Use `Maybe` / `Either` (or `ExceptT`) for expected failures and `throwIO` with a custom exception type for IO failures. Add context in the error value or exception.
- Red flags: partial functions (`head`, `tail`, `fromJust`, `read`, `!!`) on data that can be empty or invalid; `error` for anything other than truly impossible states; catching `SomeException` and continuing; lazy `IO` reads that defer errors to an unexpected place.
- Use `NonEmpty`, pattern matching, and `readMaybe` instead. Turn on `-Wincomplete-patterns` (part of `-Wall`) and treat it as an error.

## Representation: algebraic data types and maps

```haskell
data Zone = Bkk | Central | North | Other
  deriving (Show, Eq, Ord, Enum, Bounded)

zoneFee :: Zone -> Int
zoneFee Bkk     = 40
zoneFee Central = 60
zoneFee North   = 80
zoneFee Other   = 100
```

Or `Map.fromList` for data loaded at runtime. Make illegal states unrepresentable with sum types, `newtype` wrappers, and smart constructors.

## Least Surprise: Haskell conventions

- camelCase for values and functions, PascalCase for types and constructors.
- Instances must obey their laws (Functor, Monad, Semigroup, Eq); `Show` output should be valid Haskell; avoid orphan instances.
- Use `Text` (not `String`) for real text data and `ByteString` for binary.
- Follow `hlint` suggestions unless there is a clear reason not to.

## Silence

Results to stdout, diagnostics with `hPutStrLn stderr`, failure via `exitFailure` or `die`. Never commit `Debug.Trace` calls. Use a logging library (`katip`, `co-log`) with levels for services.

## Generation

`deriving` (`stock`, `newtype`, `anyclass`, `via`) with `Generic` for `aeson` instances, `servant` to derive clients and docs from one API type, `proto-lens` for protobuf, Template Haskell sparingly (e.g. `makeLenses`).

## Optimization

Measure with `criterion` or `tasty-bench`, and profile with `cabal build --enable-profiling` plus `+RTS -p -hT`. Most real problems are space leaks from laziness: use `foldl'`, strict fields (`!`), and `Data.Map.Strict`. Pick the right container (`Vector`, `IntMap`, `HashMap`) before tuning code.

## Extensibility

Use records with named fields so new fields don't break callers, hide constructors behind smart constructors, parse JSON with optional fields (`.:?`) and a version field, and follow the PVP for package versions.
