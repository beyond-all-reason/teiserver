defmodule Central.MixProject do
  use Mix.Project

  def project do
    [
      app: :central,
      version: "0.1.0",
      elixir: ">= 1.12.2",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:phoenix, :gettext] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
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
      mod: {Central.Application, []},
      extra_applications: [:logger, :runtime_tools, :os_mon, :iex]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # Default phoenix deps
      {:phoenix, "~> 1.6.2"},
      {:phoenix_ecto, "~> 4.4"},
      {:ecto_sql, "~> 3.6"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_html, "~> 3.0"},
      {:phoenix_live_reload, "~> 1.3.2", only: :dev},
      {:phoenix_live_view, "~> 0.17"},
      {:floki, ">= 0.31.0", only: :test},
      {:phoenix_live_dashboard, "~> 0.6"},
      {:esbuild, "~> 0.2", runtime: Mix.env() == :dev},
      {:bamboo, "~> 2.1"},
      {:bamboo_smtp, "~> 4.0"},
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 0.18"},
      {:jason, "~> 1.2"},
      {:plug_cowboy, "~> 2.5"},

      # Extra deps
      {:ecto_psql_extras, "~> 0.7"},
      {:logger_file_backend, "~> 0.0.10"},
      {:timex, "~> 3.7.5"},
      {:breadcrumble, "~> 1.0.0"},
      {:guardian, "~> 2.1"},
      {:argon2_elixir, "~> 2.3"},
      {:bodyguard, "~> 2.4"},
      {:human_time, "~> 0.3.0"},
      {:oban, "~> 2.11"},
      {:parallel, "~> 0.0"},
      {:con_cache, "~> 1.0"},
      {:phoenix_pubsub, "~> 2.0"},
      {:elixir_uuid, "~> 1.2"},
      {:excoveralls, "~> 0.14.1", only: :test},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.1", only: [:dev], runtime: false},
      {:dart_sass, "~> 0.3", only: [:dev]},
      {:libcluster, "~> 3.3"},

      # Teiserver libs
      {:cowboy, "~> 2.9"},
      {:statistics, "~> 0.6.2"},
      {:csv, "~> 2.4"},
      {:earmark, "~> 1.4"},
      {:ranch, "~> 1.8"},
      {:alchemy, "~> 0.7.0", hex: :discord_alchemy},
      {:horde, "~> 0.8"},
      {:etop, "~> 0.7.0"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.deploy": [
        "esbuild default --minify",
        "sass dark --no-source-map --style=compressed",
        "sass light --no-source-map --style=compressed",
        "phx.digest"
      ]
    ]
  end
end
