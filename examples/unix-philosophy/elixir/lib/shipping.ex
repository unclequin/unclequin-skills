defmodule Shipping do
  @zone_fees %{bkk: 40, central: 60, north: 80, other: 100}

  def zone_fee(zone), do: Map.fetch!(@zone_fees, zone)
end
