defmodule Teiserver.Startup do
  @moduledoc false
  use TeiserverWeb, :startup
  require Logger
  alias Phoenix.PubSub

  @spec startup :: :ok
  def startup do
    start_time = System.system_time(:millisecond)

    Teiserver.TeiserverConfigs.teiserver_configs()

    Teiserver.LobbyIdServer.start_lobby_id_server()

    Teiserver.Tachyon.CommandDispatch.build_dispatch_cache()
    Teiserver.Tachyon.Schema.load_schemas()

    Teiserver.Lobby.CommandLib.cache_lobby_commands()
    Teiserver.Bridge.CommandLib.cache_discord_commands()
    Teiserver.Communication.pre_cache_discord_channels()

    add_audit_types([
      "Account:User password reset",
      "Account:Failed login",
      "Account:Created user",
      "Account:Updated user",
      "Account:Updated user permissions",
      "Account:User registration",
      "Account:Updated report",
      "Site config:Update value",
      "Moderation:Ban enabled",
      "Moderation:Ban disabled",
      "Moderation:Ban updated",
      "Moderation:Ban enacted",
      "Moderation:Action deleted",
      "Moderation:Action halted",
      "Moderation:Action re_posted",
      "Moderation:Action updated",
      "Moderation:Action created",
      "Moderation:De-bridged user",
      "Moderation:Mark as smurf",
      "Teiserver:Updated automod action",
      "Teiserver:Automod action enacted",
      "Teiserver:De-bridged user",
      "Teiserver:Changed user rating",
      "Teiserver:Changed user name",
      "Teiserver:Smurf merge",
      "Microblog.delete_post",
      "Discord.text_callback"
    ])

    Teiserver.cache_put(:lists, :rooms, [])
    Teiserver.cache_put(:lists, :lobby_policies, [])

    Teiserver.Data.Matchmaking.pre_cache_queues()
    Teiserver.Game.pre_cache_policies()

    # Add in achievements
    Teiserver.Game.GenerateAchievementTypes.perform()

    if Application.get_env(:teiserver, Teiserver)[:enable_match_monitor] do
      spawn(fn ->
        :timer.sleep(200)
        Teiserver.Battle.start_match_monitor()
      end)
    end

    if Application.get_env(:teiserver, Teiserver)[:enable_coordinator_mode] do
      spawn(fn ->
        :timer.sleep(200)
        Teiserver.Coordinator.start_coordinator()
        Teiserver.Coordinator.AutomodServer.start_automod_server()
      end)
    end

    if Application.get_env(:teiserver, Teiserver)[:enable_accolade_mode] do
      spawn(fn ->
        :timer.sleep(200)
        Teiserver.Account.AccoladeLib.start_accolade_server()
      end)
    end

    Teiserver.cache_put(:application_metadata_cache, "teiserver_partial_startup_completed", true)
    Teiserver.cache_put(:application_metadata_cache, "teiserver_full_startup_completed", true)

    Teiserver.Account.LoginThrottleServer.startup()

    # Give everything else a chance to have started up
    spawn(fn ->
      :timer.sleep(1000)

      PubSub.broadcast(
        Teiserver.PubSub,
        "teiserver_server",
        %{
          channel: "teiserver_server",
          event: :started,
          node: Node.self()
        }
      )
    end)

    time_taken = System.system_time(:millisecond) - start_time

    Teiserver.Telemetry.log_complex_server_event(nil, "Server startup", %{
      time_taken_ms: time_taken
    })

    Teiserver.cache_put(:application_metadata_cache, :node_startup_datetime, Timex.now())

    Logger.info("Teiserver startup complete, took #{time_taken}ms")
  end
end
