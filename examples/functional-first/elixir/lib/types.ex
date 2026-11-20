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
