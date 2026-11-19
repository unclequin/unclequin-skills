defmodule Lifecycle do
  # The whole lifecycle. A pair that isn't here is illegal.
  @transitions %{
    {:draft, :pay} => :paid,
    {:draft, :cancel} => :cancelled,
    {:paid, :ship} => :shipped,
    {:paid, :cancel} => :cancelled
  }

  def transitions, do: @transitions

  def step(state, event) do
    case Map.fetch(@transitions, {state, event}) do
      {:ok, next} -> {:ok, next}
      :error -> {:error, {:illegal_transition, state, event}}
    end
  end

  @doc "Folds `step/2` over events and stops at the first illegal one."
  def replay(state, events) do
    Enum.reduce_while(events, {:ok, state}, fn event, {:ok, current} ->
      case step(current, event) do
        {:ok, next} -> {:cont, {:ok, next}}
        error -> {:halt, error}
      end
    end)
  end
end
