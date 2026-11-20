# Elixir Idioms for the Unix Philosophy

Elixir's pipe operator is the Unix pipe at the language level, and its runtime is a system of small processes that do one thing and talk through messages. The main risks run the other way: a `GenServer` for code that holds no state, macros where a function would do, and `rescue` used to keep going after something broke. Run `mix format --check-formatted`, `mix compile --warnings-as-errors`, and Credo.

## Modularity: small modules, one way in

Each module has one job and a small public API; everything else is `defp`. Elixir can't hide a struct's fields, so give callers a constructor that validates, and mark the type `@opaque` so Dialyzer flags code that reaches inside.

```elixir
defmodule Shop.Order do
  @moduledoc "An order, and the one way to build a valid one."

  @enforce_keys [:id, :lines]
  defstruct @enforce_keys

  @opaque t :: %__MODULE__{id: String.t(), lines: [map()]}

  def new(id, lines) when is_binary(id) and is_list(lines) and lines != [] do
    {:ok, %__MODULE__{id: id, lines: lines}}
  end

  def new(id, lines), do: {:error, {:invalid_order, id, lines}}
```

## Composition: functions over enumerables, pipes at the call site

```elixir
  # Hard to compose: tied to a file
  def count_in_file(path), do: path |> File.stream!() |> Enum.count()

  # Composable: any enumerable of lines (a file stream, stdin, a list in a test)
  def count(lines), do: Enum.count(lines)

  def main do
    IO.stream(:stdio, :line) |> count() |> IO.puts()
  end
```

Accept any `Enumerable` rather than a list or a path; `File.stream!/1` and `IO.stream/2` read large inputs lazily, a line at a time. Put the data being transformed first in every function so calls chain with `|>`.

## Separation: functional core, imperative shell

Business rules are plain functions over data. Processes, I/O, and timers belong to the shell. A `GenServer` is a shell: it holds state and receives messages, and calls pure functions for every decision, so the rules are tested without starting a process. Pass policy in as data:

```elixir
defmodule Retry do
  defstruct max_attempts: 3, backoff_ms: 200

  @doc "Mechanism only: calls `fun` until it returns {:ok, _} or attempts run out."
  def with_retry(%__MODULE__{} = policy, fun), do: attempt(policy, fun, 1)
```

```elixir
    # caller chooses the policy
    Retry.with_retry(%Retry{max_attempts: 3, backoff_ms: 200}, &Partner.call/0)
```

## Simplicity: modules and functions first

- Start with a module of functions. Add a `GenServer`, `Agent`, or `Task` only when there is state to hold or work to run concurrently, not to organise code.
- Write a function before a macro. A macro is for syntax a function can't express.
- Add a behaviour or protocol when a second implementation, or a test double, needs it.
- Keep supervision trees shallow and named for what they supervise.

## Transparency and Repair: tagged tuples and loud crashes

```elixir
  # Silent failure: bad input becomes the default port
  def port_or_default(raw) do
    case Integer.parse(raw) do
      {port, ""} -> port
      _ -> 4000
    end
  end

  # Explicit failure with a clear message
  def parse_port(raw) do
    case Integer.parse(raw) do
      {port, ""} when port in 1..65_535 -> {:ok, port}
      _ -> {:error, "invalid PORT: #{inspect(raw)}"}
    end
  end

  def main do
    # fetch_env! raises if PORT is unset: fail fast
    case parse_port(System.fetch_env!("PORT")) do
      {:ok, port} ->
        serve(port)

      {:error, reason} ->
        IO.puts(:stderr, reason)
        System.halt(1)
    end
  end
```

- Return `{:ok, value}` or `{:error, reason}` for failures the caller can handle, and chain them with `with`. Name the raising variant with `!` (`fetch!`, `File.read!`), as the standard library does.
- "Let it crash" is fail-loudly: an unexpected error crashes the process, the crash is logged with its stack trace, and a supervisor restarts it from a known state.
- Red flags: `rescue _ ->` or `catch :exit, _` that carries on; `_ = File.write(...)` dropping an `{:error, _}`; `Map.get(map, key, default)` where a missing key is a bug (use `Map.fetch!`); `String.to_atom/1` on input, since atoms are never freed.

## Representation: maps and pattern-matched function heads

```elixir
defmodule Shipping do
  @zone_fees %{bkk: 40, central: 60, north: 80, other: 100}

  def zone_fee(zone), do: Map.fetch!(@zone_fees, zone)
end
```

A map in a module attribute is compiled in; load it from config or a file when it changes at runtime. When each case needs code rather than a value, use one function head per case, and let a missing case raise `FunctionClauseError`.

## Least Surprise: Elixir conventions

- `snake_case` for functions and variables, `CamelCase` for modules; a trailing `?` for predicates and `!` for functions that raise.
- The subject comes first, so the function pipes.
- Return `{:ok, _}` / `{:error, _}` or raise; never return `nil` to mean "failed" when the caller can't tell it from a real `nil`.
- `mix format` decides layout; don't argue with it.

## Silence

Results to stdout with `IO.puts`, diagnostics with `IO.puts(:stderr, ...)`, failure with `System.halt(1)` in a script or escript. Services log through `Logger` with levels and metadata, at `:info` or below for routine success. Never commit `IO.inspect` or `dbg` calls.

## Generation

Ecto schemas and changesets from one definition of the data, `OpenApiSpex` for OpenAPI documents and validation, `protobuf` (elixir-protobuf) for protobuf, and `mix phx.gen.*` for scaffolding you then edit by hand.

## Optimization

Measure with Benchee and profile with `mix profile.tprof` or `:eprof`. Common real costs: `++` in a loop (prepend, then `Enum.reverse/1`), building strings by concatenation (use iodata), a single `GenServer` that serialises every request (read from ETS instead), and copying large terms between processes.

## Extensibility

Give structs defaults so new fields don't break callers, accept keyword options (`opts \\ []`) for new behaviour, define behaviours for plug-in points, and follow semantic versioning for Hex packages.

A version may add to the set of messages it accepts, never take from it:

```elixir
  @typedoc "Version 1 of the quote request."
  @type v1 :: %{sku: String.t(), quantity: pos_integer()}

  @typedoc "Version 2 adds an optional coupon, so every v1 map is still a v2 map."
  @type v2 :: %{
          required(:sku) => String.t(),
          required(:quantity) => pos_integer(),
          optional(:coupon) => String.t()
        }
```

```elixir
  @spec quote_v1(v1()) :: pos_integer()
  def quote_v1(%{sku: sku, quantity: quantity}), do: Map.fetch!(@prices, sku) * quantity

  @spec quote_v2(v2()) :: pos_integer()
  def quote_v2(%{sku: sku, quantity: quantity} = request) do
    total = Map.fetch!(@prices, sku) * quantity

    case Map.fetch(request, :coupon) do
      :error -> total
      {:ok, coupon} -> total - div(total * Map.fetch!(@percent_off, coupon), 100)
    end
  end
```

The compiler checks none of this: the `optional(:coupon)` key says every v1 map is a v2 map, and Dialyzer can hold callers to the specs, but nothing stops a build. A test checks both halves, that each version 1 request is still accepted and gets the same answer, with the old handler kept as the spec:

```elixir
  test "version 2 answers every version 1 request the same" do
    for sku <- Pricing.skus(), quantity <- 1..100 do
      request = %{sku: sku, quantity: quantity}
      assert Pricing.quote_v2(request) == Pricing.quote_v1(request)
    end
  end
```

A `GenServer` works the same way: the messages its `handle_call` clauses match are its message set. A new version may add a clause, such as `{:quote, sku, quantity, coupon}`, but must keep every old clause, such as `{:quote, sku, quantity}`, matching and replying as before; the same test, run through `GenServer.call`, checks it.

Making `coupon` required, or renaming `quantity`, would make the old requests fail to match, and the test would fail. That is the signal for a new major version, served beside the old one.
