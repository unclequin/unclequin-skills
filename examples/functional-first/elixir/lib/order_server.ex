defmodule OrderServer do
  @moduledoc "One order's lifecycle as a process. Its interface is `message`."
  use GenServer

  @typedoc "Every message the server handles, and nothing else."
  @type message :: :pay | :ship | :cancel | :accepts

  def start_link(state), do: GenServer.start_link(__MODULE__, state)

  @spec call(GenServer.server(), message()) :: :ok | {:error, term()} | [atom()]
  def call(server, message), do: GenServer.call(server, message)

  @impl true
  def init(state), do: {:ok, state}

  @impl true
  def handle_call(:accepts, _from, state), do: {:reply, OrderState.accepts(state), state}

  def handle_call(event, _from, state) when event in [:pay, :ship, :cancel] do
    case Lifecycle.step(state, event) do
      {:ok, next} -> {:reply, :ok, next}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end
end
