defmodule Settings do
  # Silent failure: bad input becomes the default port
  def port_or_default(raw) do
    case Integer.parse(raw) do
      {port, ""} -> port
      _ -> 4000
    end
  end

  # Explicit failure with a clear message
  def parse_port(raw) do
    case Integer.parse(raw) do
      {port, ""} when port in 1..65_535 -> {:ok, port}
      _ -> {:error, "invalid PORT: #{inspect(raw)}"}
    end
  end

  def main do
    # fetch_env! raises if PORT is unset: fail fast
    case parse_port(System.fetch_env!("PORT")) do
      {:ok, port} ->
        serve(port)

      {:error, reason} ->
        IO.puts(:stderr, reason)
        System.halt(1)
    end
  end

  defp serve(port), do: {:serving, port}
end
