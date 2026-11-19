defmodule Retry do
  defstruct max_attempts: 3, backoff_ms: 200

  @doc "Mechanism only: calls `fun` until it returns {:ok, _} or attempts run out."
  def with_retry(%__MODULE__{} = policy, fun), do: attempt(policy, fun, 1)

  defp attempt(policy, fun, n) do
    case fun.() do
      {:ok, _} = ok ->
        ok

      {:error, _} = error when n >= policy.max_attempts ->
        error

      {:error, _} ->
        Process.sleep(policy.backoff_ms)
        attempt(policy, fun, n + 1)
    end
  end
end

defmodule Partner do
  def call, do: {:ok, :pong}

  def fetch do
    # caller chooses the policy
    Retry.with_retry(%Retry{max_attempts: 3, backoff_ms: 200}, &Partner.call/0)
  end
end
