defmodule Teiserver.MixProject do
  use Mix.Project

  def project do
    [
      app: :teiserver,
      version: "0.1.0",
      elixir: "~> 1.11",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Teiserver.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ranch, "~> 1.4"},
      {:parallel, "~> 0.0"},
      {:con_cache, "~> 0.13"},
      {:phoenix_pubsub, "~> 2.0"},
      {:excoveralls, "~> 0.12.3", only: :test},
      {:credo, "~> 1.2", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 0.5", only: [:dev], runtime: false}
    ]
  end
end
