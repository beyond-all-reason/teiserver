defmodule Teiserver.MixProject do
  use Mix.Project

  def project do
    [
      app: :teiserver,
      version: "0.1.0",
      elixir: "~> 1.11",
      start_permanent: Mix.env() == :prod,
      deps: deps()
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
      # {:secure_random, "~> 0.5"},

      {:con_cache, "~> 0.13"},
      {:phoenix_pubsub, "~> 2.0"},
      # {:jason, "~> 1.0"},
      # {:xmlrpc, git: "https://github.com/Teifion/elixir-xml_rpc.git"},
    ]
  end
end
