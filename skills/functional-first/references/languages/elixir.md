# Elixir: Functional First

Elixir's data is immutable and its functions are already pure unless they touch a process, a port, or the outside world, so the composed spec is the natural first draft: a pipeline of `Enum` calls over named predicates. Pattern matching on tagged tuples makes the transition table a map, and `Enum.reduce_while` is replay. The derivation risks are eager `Enum` pipelines that build a list per step, and floats for money.

## Compose: a pipeline of named predicates

```elixir
defmodule Order do
  @enforce_keys [:id, :total, :paid_in, :refunded]
  defstruct @enforce_keys

  # total is in cents; paid_in is {year, month} or nil when unpaid
  @type t :: %__MODULE__{
          id: String.t(),
          total: non_neg_integer(),
          paid_in: {integer(), 1..12} | nil,
          refunded: boolean()
        }
end
```

```elixir
  def paid_in?(%Order{paid_in: paid_in}, month), do: paid_in == month

  def refunded?(%Order{refunded: refunded}), do: refunded

  @doc """
  Revenue for a month is the sum of the totals of orders paid in that
  month, except refunded ones. A refund at any time excludes the order.
  """
  def monthly_revenue(orders, month) do
    orders
    |> Enum.filter(&paid_in?(&1, month))
    |> Enum.reject(&refunded?/1)
    |> Enum.map(& &1.total)
    |> Enum.sum()
  end
```

The pipe reads top to bottom as the set expression `Σ total over PaidIn(m) \ Refunded`: `filter` is the set, `reject` is "except", `sum` is the aggregation, each step its own line. Name predicates with a trailing `?`, as the standard library does. Keep money in integer cents (or the `Decimal` library); floats change the sum with the order of addition.

## Derive: group instead of rescanning

```elixir
  @doc "Spec: twelve passes, one per month."
  def revenue_by_month_spec(orders, year) do
    for month <- 1..12, do: monthly_revenue(orders, {year, month})
  end

  @doc "Derived from `revenue_by_month_spec/2` by grouping instead of rescanning."
  def revenue_by_month(orders, year) do
    sums =
      for %Order{paid_in: {^year, month}} = order <- orders,
          not refunded?(order),
          reduce: %{} do
        acc -> Map.update(acc, month, order.total, &(&1 + order.total))
      end

    for month <- 1..12, do: Map.get(sums, month, 0)
  end
```

The comprehension's pattern `{^year, month}` selects and destructures in one place; orders that don't match (unpaid, another year) are skipped, which is the filter. `reduce:` makes it one pass. `Enum.group_by/3` followed by summing each group is the clearer middle step when one pass isn't needed.

Every `Enum` function returns a new list, so a five-step pipeline over a large input builds four intermediate lists. `Stream` fuses the steps lazily, but each element then pays for the laziness, so it is often slower on small inputs. Measure with Benchee before switching. Integers are arbitrary precision, so the derived sum can't overflow where the spec didn't.

## State machine: a map as the table

```elixir
defmodule Lifecycle do
  # The whole lifecycle. A pair that isn't here is illegal.
  @transitions %{
    {:draft, :pay} => :paid,
    {:draft, :cancel} => :cancelled,
    {:paid, :ship} => :shipped,
    {:paid, :cancel} => :cancelled
  }

  def transitions, do: @transitions

  def step(state, event) do
    case Map.fetch(@transitions, {state, event}) do
      {:ok, next} -> {:ok, next}
      :error -> {:error, {:illegal_transition, state, event}}
    end
  end

  @doc "Folds `step/2` over events and stops at the first illegal one."
  def replay(state, events) do
    Enum.reduce_while(events, {:ok, state}, fn event, {:ok, current} ->
      case step(current, event) do
        {:ok, next} -> {:cont, {:ok, next}}
        error -> {:halt, error}
      end
    end)
  end
end
```

The module attribute is the table, compiled in as a literal map. `reduce_while` with `{:halt, error}` is the whole "stop at the first illegal event" rule. When states carry data, make them tuples (`{:issued, term}`) and keep the map as the list of legal moves between their tags.

A long-lived entity often lives in a process (a `GenServer` or `:gen_statem`). The process is the imperative shell: it holds the current state, receives events as messages, and does the I/O. Every decision stays in the pure `step/2`, called from `handle_call` or `handle_cast`, so the lifecycle is tested without starting a process.

## Types: sets of values, sets of messages

```elixir
defmodule OrderRecord do
  # Before: three flags and two optional fields allow 2³ combinations of flags,
  # each with or without an amount and a tracking number. Four are legal.
  defstruct paid: false, shipped: false, cancelled: false, amount: nil, tracking: nil

  @type t :: %__MODULE__{
          paid: boolean(),
          shipped: boolean(),
          cancelled: boolean(),
          amount: non_neg_integer() | nil,
          tracking: String.t() | nil
        }
end
```

```elixir
defmodule Amount do
  @moduledoc "An amount in integer cents, greater than zero. Only `parse/1` makes one."
  @enforce_keys [:cents]
  defstruct @enforce_keys

  @opaque t :: %__MODULE__{cents: pos_integer()}

  @doc "Parses raw input at the boundary; the core takes only `Amount.t()`."
  @spec parse(String.t()) :: {:ok, t()} | {:error, String.t()}
  def parse(raw) when is_binary(raw) do
    with true <- raw =~ ~r/\A[0-9]+\z/,
         cents when cents > 0 <- String.to_integer(raw) do
      {:ok, %__MODULE__{cents: cents}}
    else
      _ -> {:error, "invalid amount: #{inspect(raw)}"}
    end
  end

  @spec cents(t()) :: pos_integer()
  def cents(%__MODULE__{cents: cents}), do: cents
end
```

`@opaque` tells Dialyzer to warn when code outside `Amount` builds the struct or reads its field. That is the only guard: at run time `%Amount{cents: -1}` is an ordinary map, so the rule holds by convention and Dialyzer, not by the compiler.

```elixir
defmodule OrderState do
  # After: one tuple per state, each holding only its own data.
  @type t ::
          {:draft, id :: String.t()}
          | {:paid, id :: String.t(), Amount.t()}
          | {:shipped, id :: String.t(), Amount.t(), tracking :: String.t()}
          | {:cancelled, id :: String.t()}

  @doc "The amount to refund on cancellation: only money that was taken."
  @spec refund_due(t()) :: non_neg_integer()
  def refund_due({:draft, _id}), do: 0
  def refund_due({:cancelled, _id}), do: 0
  def refund_due({:paid, _id, amount}), do: Amount.cents(amount)
  def refund_due({:shipped, _id, amount, _tracking}), do: Amount.cents(amount)
```

Elixir doesn't check that the clauses cover the union: a fifth state raises `FunctionClauseError` when it arrives, so give each state a test. From 1.19 on, the compiler runs its own checker built on set-theoretic types: unions, intersections, and negations, with `term()` for every value and `none()` for no value. It infers those types from patterns and guards and prints them in its warnings, marking with dashes an argument it can prove won't match (`-{:draft, binary()}-`). You can't write those types in a signature yet, so `@type` and `@spec` stay as documentation and Dialyzer's input.

```elixir
  @doc "The messages a state accepts, read from the transition table."
  @spec accepts(atom()) :: [atom()]
  def accepts(state) do
    for {{^state, event}, _next} <- Lifecycle.transitions(), do: event
  end

  # Each operation matches only the state that accepts it.
  def pay({:draft, id}, amount), do: {:paid, id, amount}
  def ship({:paid, id, amount}, tracking), do: {:shipped, id, amount, tracking}
  def cancel({:draft, id}), do: {:cancelled, id}
  def cancel({:paid, id, _amount}), do: {:cancelled, id}
end
```

Elixir has no compile-time typestate. `ship/2` matches only a paid order, so shipping a draft raises at run time. The 1.20 compiler goes further when it can see the argument: `ship({:draft, "o1"}, "T1")` is a type warning, and an error under `--warnings-as-errors`. A state that is only known at run time gets no warning, so `Lifecycle.step/2` stays the check.

A process's interface is the set of messages it handles. Write that set as one `@type`, and let every `handle_call` clause pass the decision to the pure `step/2`:

```elixir
defmodule OrderServer do
  @moduledoc "One order's lifecycle as a process. Its interface is `message`."
  use GenServer

  @typedoc "Every message the server handles, and nothing else."
  @type message :: :pay | :ship | :cancel | :accepts

  def start_link(state), do: GenServer.start_link(__MODULE__, state)

  @spec call(GenServer.server(), message()) :: :ok | {:error, term()} | [atom()]
  def call(server, message), do: GenServer.call(server, message)

  @impl true
  def init(state), do: {:ok, state}

  @impl true
  def handle_call(:accepts, _from, state), do: {:reply, OrderState.accepts(state), state}

  def handle_call(event, _from, state) when event in [:pay, :ship, :cancel] do
    case Lifecycle.step(state, event) do
      {:ok, next} -> {:reply, :ok, next}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end
end
```

A message outside the union matches no clause and crashes the server, which is the failure you want: loud, and handled by its supervisor.

## Check: properties

With StreamData:

```elixir
  defp order do
    gen all id <- string(:alphanumeric),
            total <- integer(0..1000),
            paid_in <- one_of([constant(nil), tuple({member_of([2024, 2025]), integer(1..12)})]),
            refunded <- boolean() do
      %Order{id: id, total: total, paid_in: paid_in, refunded: refunded}
    end
  end

  property "the derived revenue equals the spec" do
    check all orders <- list_of(order()) do
      assert Revenue.revenue_by_month(orders, 2024) == Revenue.revenue_by_month_spec(orders, 2024)
    end
  end

  property "step follows the table" do
    check all events <- list_of(member_of([:pay, :ship, :cancel])) do
      Enum.reduce(events, :draft, fn event, state ->
        case Lifecycle.step(state, event) do
          {:ok, next} ->
            assert Lifecycle.transitions()[{state, event}] == next
            next

          {:error, {:illegal_transition, ^state, ^event}} ->
            refute Map.has_key?(Lifecycle.transitions(), {state, event})
            state
        end
      end)
    end
  end

  test "the table matches the requirement's list of allowed moves" do
    allowed = [
      {:draft, :pay, :paid},
      {:draft, :cancel, :cancelled},
      {:paid, :ship, :shipped},
      {:paid, :cancel, :cancelled}
    ]

    assert Lifecycle.transitions() == Map.new(allowed, fn {s, e, n} -> {{s, e}, n} end)
  end
```

`use ExUnitProperties` in the test module brings in `property`, `check all`, and the generators; StreamData shrinks a failing list to a small one. The last test is the one that catches a wrong entry in the table: "step follows the table" passes either way, because it reads the same table it checks.

```elixir
  @states [:draft, :paid, :shipped, :cancelled]
  @events [:pay, :ship, :cancel]

  test "a state accepts exactly the events step allows" do
    for state <- @states do
      allowed = for event <- @events, match?({:ok, _}, Lifecycle.step(state, event)), do: event
      assert Enum.sort(OrderState.accepts(state)) == Enum.sort(allowed)
    end
  end

  property "parse accepts exactly the positive whole numbers of cents" do
    check all raw <- one_of([string(:printable), map(integer(), &Integer.to_string/1)]) do
      positive? = raw =~ ~r/\A[0-9]+\z/ and String.to_integer(raw) > 0
      assert match?({:ok, _}, Amount.parse(raw)) == positive?
    end

    check all cents <- positive_integer() do
      assert {:ok, amount} = Amount.parse(Integer.to_string(cents))
      assert Amount.cents(amount) == cents
    end
  end

  test "the server answers its messages from the table" do
    {:ok, order} = OrderServer.start_link(:draft)

    assert OrderServer.call(order, :accepts) == [:cancel, :pay]
    assert OrderServer.call(order, :ship) == {:error, {:illegal_transition, :draft, :ship}}
    assert OrderServer.call(order, :pay) == :ok
    assert OrderServer.call(order, :accepts) == [:cancel, :ship]
    assert OrderServer.call(order, :ship) == :ok
    assert OrderServer.call(order, :accepts) == []
  end
```

The server test only sends messages and checks the replies. It never reads the process's state with `:sys.get_state/1`, so it keeps passing if the state's shape changes. There's no test that shipping a draft fails to compile: ExUnit has no standard way to assert it, and the warning depends on the Elixir version.

## Tooling

- Measure before deriving: Benchee for benchmarks, and `mix profile.tprof` (or `:eprof`, `:fprof`) for where time goes.
- `mix format --check-formatted`, `mix compile --warnings-as-errors`, Credo for style, and Dialyzer (through `dialyxir`) for type specs. Elixir's compiler also reports type mismatches it can infer.
