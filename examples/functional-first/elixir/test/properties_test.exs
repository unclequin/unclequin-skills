defmodule PropertiesTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

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

  test "replay stops at the first illegal event" do
    assert Lifecycle.replay(:draft, [:pay, :ship]) == {:ok, :shipped}

    assert Lifecycle.replay(:draft, [:ship, :pay]) ==
             {:error, {:illegal_transition, :draft, :ship}}
  end
end
