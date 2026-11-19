defmodule Shop.Order do
  @moduledoc "An order, and the one way to build a valid one."

  @enforce_keys [:id, :lines]
  defstruct @enforce_keys

  @opaque t :: %__MODULE__{id: String.t(), lines: [map()]}

  def new(id, lines) when is_binary(id) and is_list(lines) and lines != [] do
    {:ok, %__MODULE__{id: id, lines: lines}}
  end

  def new(id, lines), do: {:error, {:invalid_order, id, lines}}

  def total(%__MODULE__{lines: lines}), do: Enum.sum_by(lines, & &1.price)
end
