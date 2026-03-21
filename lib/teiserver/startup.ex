defmodule Teiserver.Startup do
  @moduledoc false

  alias Phoenix.PubSub
  alias Teiserver.Battle
  alias Teiserver.Bridge.CommandLib
  alias Teiserver.Communication
  alias Teiserver.Coordinator
  alias Teiserver.Coordinator.AutomodServer
  alias Teiserver.Game.GenerateAchievementTypes
  alias Teiserver.LobbyIdServer
  alias Teiserver.Telemetry
  use TeiserverWeb, :startup
  require Logger

  @spec startup :: :ok
  def startup do
    start_time = System.system_time(:millisecond)

    LobbyIdServer.start_lobby_id_server()

    CommandLib.cache_discord_commands()
    Communication.pre_cache_discord_channels()

    # Add in achievements
    GenerateAchievementTypes.perform()

    if Application.get_env(:teiserver, Teiserver)[:enable_match_monitor] do
      spawn(fn ->
        :timer.sleep(200)
        Battle.start_match_monitor()
      end)
    end

    if Application.get_env(:teiserver, Teiserver)[:enable_coordinator_mode] do
      spawn(fn ->
        :timer.sleep(200)
        Coordinator.start_coordinator()
        AutomodServer.start_automod_server()
      end)
    end

    Teiserver.cache_put(:application_metadata_cache, "teiserver_partial_startup_completed", true)
    Teiserver.cache_put(:application_metadata_cache, "teiserver_full_startup_completed", true)

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

    Telemetry.log_complex_server_event(nil, "Server startup", %{
      time_taken_ms: time_taken
    })

    Teiserver.cache_put(:application_metadata_cache, :node_startup_datetime, Timex.now())

    Logger.info("Teiserver startup complete, took #{time_taken}ms")
  end
end
