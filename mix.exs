defmodule Teiserver.MixProject do
  use Mix.Project

  def project do
    [
      app: :teiserver,
      version: "0.1.0",
      elixir: ">= 1.12.2",
      description: description(),
      package: package(),
      dialyzer: dialyzer(),
      elixirc_paths: elixirc_paths(Mix.env()),
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

  defp description do
    """
    Middleware server for online gaming
    """
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    # get that with mix app.tree nostrum
    nostrum_extras = [:certifi, :gun, :inets, :jason, :mime]

    [
      mod: {Teiserver.Application, []},
      included_applications: [:nostrum],
      extra_applications: [:logger, :runtime_tools, :os_mon, :iex] ++ nostrum_extras
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(:dev), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # Default phoenix deps
      {:phoenix, "~> 1.7"},
      {:phoenix_ecto, "~> 4.6"},
      {:ecto_sql, "~> 3.12"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_html, "~> 4.2"},
      {:phoenix_live_reload, "~> 1.5", only: :dev},
      {:phoenix_live_view, "~> 1.0"},
      # see https://hexdocs.pm/phoenix_html/changelog.html#v4-0-0-2023-12-19
      {:phoenix_html_helpers, "~> 1.0"},
      {:floki, ">= 0.37.0", only: :test},
      {:phoenix_live_dashboard, "~> 0.8"},
      {:esbuild, "~> 0.9", runtime: Mix.env() == :dev},
      {:bamboo, "~> 2.1"},
      {:bamboo_smtp, "~> 4.0"},
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 0.20"},
      {:jason, "~> 1.2"},
      {:plug_cowboy, "~> 2.5"},

      # Temporary deps while we transition away from views
      {:phoenix_view, "~> 2.0"},

      # Extra deps
      {:logger_file_backend, "~> 0.0.14"},
      {:logger_backends, "~> 1.0"},
      {:ecto_psql_extras, "~> 0.8"},
      {:timex, "~> 3.7.11"},
      {:breadcrumble, "~> 1.0.0"},
      {:guardian, "~> 2.1"},
      {:argon2_elixir, "~> 4.1"},
      {:bodyguard, "~> 2.4"},
      {:human_time, "~> 0.3.0"},
      {:oban, "~> 2.15"},
      {:parallel_stream, "~> 1.1.0"},
      {:con_cache, "~> 1.0"},
      {:phoenix_pubsub, "~> 2.0"},
      {:elixir_uuid, "~> 1.2"},
      {:excoveralls, "~> 0.15.3", only: :test, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.1", only: [:dev, :test], runtime: false},
      {:dart_sass, "~> 0.7", only: [:dev]},
      {:tzdata, "~> 1.1.2"},
      {:ex_ulid, "~> 0.1.0"},
      {:mock, "~> 0.3.0", only: :test},

      # Teiserver libs
      {:openskill,
       git: "https://github.com/beyond-all-reason/openskill.ex.git", branch: "master"},
      {:cowboy, "~> 2.9"},
      {:statistics, "~> 0.6.2"},
      {:csv, "~> 2.4"},
      {:mdex, "~> 0.2"},
      {:ranch, "~> 1.8"},
      {:horde, "~> 0.9"},
      {:etop, "~> 0.7.0"},
      {:cowlib, "~> 2.11", hex: :remedy_cowlib, override: true},
      {:json_xema, "~> 0.3"},
      {:nostrum, "~> 0.10"},

      # gun is a transitive dependency of nostrum. The version 2.1.0 works,
      # while the next one, 2.2.0 produces the following error when starting
      # with the discord bridge enabled
      # 2025-05-15 11:31:53.669 [error] pid=<0.4991.0>  ** State machine <0.4991.0> terminating
      # ** Last event = {cast,{request,<0.4981.0>,#Ref<0.545224783.3581673475.65925>,
      #                                <<"GET">>,<<"/api/v10/gateway/bot?">>,
      #                                [{<<"authorization">>, <<...>>
      #  {<<"user-agent">>,
      #                                  <<"DiscordBot (https://github.com/kraigie/nostrum, 0.10.4)">>}],
      #                                <<>>,infinity}}
      # ** When server state  = {connected,
      #                          {state,<0.4981.0>,
      #                           {up,#Ref<0.545224783.3581673475.65884>},
      #                           "discord.com",443,<<"https">>,"discord.com",443,[],
      #                           #{retry => 0,connect_timeout => 5000,
      #                             domain_lookup_timeout => 5000,
      #                             tls_handshake_timeout => 5000,
      #                             tls_opts =>
      #                              [{verify,verify_peer},
      #                               {cacerts,
      #
      # So pin this down
      {:gun, "== 2.1.0"},

      # nostrum and hackney both depends on certifi, but they resolve to diffenrent
      # versions, which screws over elixir-ls.
      {:certifi, "~> 2.13.0", override: true},
      {:websocket_sync_client,
       git: "https://github.com/geekingfrog/websocket_sync_client.git",
       ref: "d655018589f9ade836afb8df8ed5f45f53500173",
       only: [:dev, :test]}
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

  defp dialyzer do
    [
      plt_core_path: "priv/plts",
      plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
      plt_add_apps: [:ex_unit, :mix, :nostrum]
    ]
  end

  defp package do
    [
      files: ["lib", "mix.exs", "README.md", "license.md"],
      maintainers: ["Teifion Jordan"],
      licenses: ["MIT"],
      links: %{
        Changelog: "https://github.com/beyond-all-reason/teiserver/blob/master/changelog.md",
        GitHub: "https://github.com/beyond-all-reason/teiserver"
      }
    ]
  end
end
