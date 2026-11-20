defmodule TypesTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

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

  test "refund_due is the amount only for money that was taken" do
    {:ok, amount} = Amount.parse("500")
    draft = {:draft, "o1"}
    paid = OrderState.pay(draft, amount)

    assert OrderState.refund_due(draft) == 0
    assert OrderState.refund_due(paid) == 500
    assert OrderState.refund_due(OrderState.ship(paid, "T1")) == 500
    assert OrderState.refund_due(OrderState.cancel(paid)) == 0
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
end
