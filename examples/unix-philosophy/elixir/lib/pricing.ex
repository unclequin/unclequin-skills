defmodule Pricing do
  @prices %{"apple" => 100, "pear" => 150}
  @percent_off %{"TENOFF" => 10}

  @typedoc "Version 1 of the quote request."
  @type v1 :: %{sku: String.t(), quantity: pos_integer()}

  @typedoc "Version 2 adds an optional coupon, so every v1 map is still a v2 map."
  @type v2 :: %{
          required(:sku) => String.t(),
          required(:quantity) => pos_integer(),
          optional(:coupon) => String.t()
        }

  def skus, do: Map.keys(@prices)

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
end
