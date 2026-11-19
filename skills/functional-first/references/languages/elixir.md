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

## Tooling

- Measure before deriving: Benchee for benchmarks, and `mix profile.tprof` (or `:eprof`, `:fprof`) for where time goes.
- `mix format --check-formatted`, `mix compile --warnings-as-errors`, Credo for style, and Dialyzer (through `dialyxir`) for type specs. Elixir's compiler also reports type mismatches it can infer.
