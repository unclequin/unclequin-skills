defmodule LineCount do
  # Hard to compose: tied to a file
  def count_in_file(path), do: path |> File.stream!() |> Enum.count()

  # Composable: any enumerable of lines (a file stream, stdin, a list in a test)
  def count(lines), do: Enum.count(lines)

  def main do
    IO.stream(:stdio, :line) |> count() |> IO.puts()
  end
end
