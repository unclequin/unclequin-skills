defmodule ExamplesTest do
  use ExUnit.Case, async: true

  test "an order needs an id and at least one line" do
    assert {:ok, order} = Shop.Order.new("o1", [%{price: 300}, %{price: 200}])
    assert Shop.Order.total(order) == 500
    assert {:error, {:invalid_order, "o1", []}} = Shop.Order.new("o1", [])
  end

  test "line counts work on any enumerable" do
    assert LineCount.count(["a\n", "b\n"]) == 2
  end

  test "retry stops at the first success and gives up after max_attempts" do
    assert Partner.fetch() == {:ok, :pong}

    {:ok, calls} = Agent.start_link(fn -> 0 end)

    fail = fn ->
      Agent.update(calls, &(&1 + 1))
      {:error, :down}
    end

    assert Retry.with_retry(%Retry{max_attempts: 3, backoff_ms: 0}, fail) == {:error, :down}
    assert Agent.get(calls, & &1) == 3
  end

  test "a bad port is an error, not a default" do
    assert Settings.parse_port("8080") == {:ok, 8080}
    assert {:error, "invalid PORT: \"80x\""} = Settings.parse_port("80x")
    assert Settings.port_or_default("80x") == 4000
  end

  test "zone fees come from the table, and an unknown zone fails loudly" do
    assert Shipping.zone_fee(:north) == 80
    assert_raise KeyError, fn -> Shipping.zone_fee(:moon) end
  end

  test "version 2 answers every version 1 request the same" do
    for sku <- Pricing.skus(), quantity <- 1..100 do
      request = %{sku: sku, quantity: quantity}
      assert Pricing.quote_v2(request) == Pricing.quote_v1(request)
    end
  end

  test "version 2's coupon changes only the new requests" do
    assert Pricing.quote_v2(%{sku: "pear", quantity: 3, coupon: "TENOFF"}) == 405

    assert_raise KeyError, fn ->
      Pricing.quote_v2(%{sku: "pear", quantity: 3, coupon: "BOGUS"})
    end
  end
end
