defmodule FunctionalFirstExamples.MixProject do
  use Mix.Project

  def project do
    [
      app: :functional_first_examples,
      version: "0.1.0",
      elixir: "~> 1.18",
      deps: [{:stream_data, "~> 1.1", only: [:dev, :test]}]
    ]
  end
end
