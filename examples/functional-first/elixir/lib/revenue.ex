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

defmodule Revenue do
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
end
