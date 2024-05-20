defmodule Teiserver.Account.PermissionCache do
  @moduledoc """
  Define caches and set them up for permission related things
  """

  use Supervisor
  import Teiserver.Account.AuthLib, only: [add_permission_set: 3]
  alias Teiserver.Helpers.CacheHelper

  def start_link(opts) do
    with {:ok, sup} <- Supervisor.start_link(__MODULE__, :ok, opts),
         :ok <- warm_permission_cache() do
      warm_restriction_cache()
      {:ok, sup}
    end
  end

  @impl true
  def init(:ok) do
    children = [
      CacheHelper.concache_perm_sup(:auth_group_store),
      CacheHelper.concache_perm_sup(:restriction_lookup_store)
    ]

    Supervisor.init(children, strategy: :one_for_all)
  end

  defp warm_permission_cache() do
    add_permission_set("admin", "debug", ~w(debug))
    add_permission_set("admin", "dev", ~w(developer structure))
    add_permission_set("admin", "admin", ~w(limited full))
    add_permission_set("admin", "report", ~w(show update delete report))
    add_permission_set("admin", "user", ~w(show create update delete report))
    add_permission_set("admin", "group", ~w(show create update delete report config))
    add_permission_set("teiserver", "admin", ~w(account battle clan queue))

    add_permission_set(
      "teiserver",
      "staff",
      ~w(overwatch reviewer moderator admin communication clan telemetry server)
    )

    add_permission_set("teiserver", "dev", ~w(infolog))
    add_permission_set("teiserver", "reports", ~w(client server match ratings infolog))
    add_permission_set("teiserver", "api", ~w(battle))

    add_permission_set(
      "teiserver",
      "player",
      ~w(account tester contributor dev streamer donor verified bot moderator)
    )

    :ok = Teiserver.Logging.Startup.startup()

    :ok
  end

  defp warm_restriction_cache() do
    # Chat stuff
    Teiserver.Account.UserLib.add_report_restriction_types("Chat", [
      "Bridging",
      "Game chat",
      "Room chat",
      "All chat"
    ])

    # Lobby interaction
    Teiserver.Account.UserLib.add_report_restriction_types("Game", [
      "Low priority",
      "All lobbies",
      "Login",
      "Permanently banned"
    ])

    Teiserver.Account.UserLib.add_report_restriction_types("Other", [
      "Accolades",
      "Boss",
      "Reporting",
      "Renaming",
      "Matchmaking"
    ])

    Teiserver.Account.UserLib.add_report_restriction_types("Warnings", [
      "Warning reminder"
    ])

    Teiserver.Account.UserLib.add_report_restriction_types("Internal", [
      "Note"
    ])
  end
end
