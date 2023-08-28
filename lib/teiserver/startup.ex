defmodule Teiserver.Startup do
  use CentralWeb, :startup
  require Logger
  alias Phoenix.PubSub

  @spec startup :: :ok
  def startup do
    start_time = System.system_time(:millisecond)

    Teiserver.Logging.Startup.startup()

    Teiserver.TeiserverConfigs.teiserver_configs()
    Teiserver.TeiserverQuickActions.teiserver_quick_actions()

    Teiserver.Communication.build_text_callback_cache()

    Teiserver.LobbyIdServer.start_lobby_id_server()
    Teiserver.SpringIdServer.start_spring_id_server()

    Teiserver.Tachyon.CommandDispatch.build_dispatch_cache()
    Teiserver.Tachyon.Schema.load_schemas()

    # Chat stuff
    Central.Account.UserLib.add_report_restriction_types("Chat", [
      "Bridging",
      "Game chat",
      "Room chat",
      "All chat"
    ])

    # Lobby interaction
    Central.Account.UserLib.add_report_restriction_types("Game", [
      "Low priority",
      "All lobbies",
      "Login",
      "Permanently banned"
    ])

    Central.Account.UserLib.add_report_restriction_types("Other", [
      "Accolades",
      "Boss",
      "Reporting",
      "Renaming",
      "Matchmaking"
    ])

    Central.Account.UserLib.add_report_restriction_types("Warnings", [
      "Warning reminder"
    ])

    add_audit_types([
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
      "Teiserver:Smurf merge"
    ])

    # Permissions setup
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

    Central.store_put(
      :application_metadata_cache,
      "random_names_3",
      ~w(tick pawn lazarus rocketeer crossbow mace centurion tumbleweed smuggler compass ghost sprinter butler webber platypus hound welder recluse archangel gunslinger sharpshooter umbrella fatboy marauder vanguard razorback titan) ++
        ~w(grunt graverobber aggravator trasher thug bedbug deceiver augur spectre fiend twitcher duck skuttle sumo arbiter manticore termite commando mammoth shiva karganeth catapult behemoth juggernaught)
    )

    Central.cache_put(:lists, :rooms, [])
    Central.cache_put(:lists, :lobby_policies, [])

    Teiserver.Data.Matchmaking.pre_cache_queues()
    Teiserver.Game.pre_cache_policies()

    # Add in achievements
    Teiserver.Game.GenerateAchievementTypes.perform()

    if Application.get_env(:central, Teiserver)[:enable_match_monitor] do
      spawn(fn ->
        :timer.sleep(200)
        Teiserver.Battle.start_match_monitor()
      end)
    end

    if Application.get_env(:central, Teiserver)[:enable_coordinator_mode] do
      spawn(fn ->
        :timer.sleep(200)
        Teiserver.Coordinator.start_coordinator()
        Teiserver.Coordinator.AutomodServer.start_automod_server()
      end)
    end

    if Application.get_env(:central, Teiserver)[:enable_accolade_mode] do
      spawn(fn ->
        :timer.sleep(200)
        Teiserver.Account.AccoladeLib.start_accolade_server()
      end)
    end

    Central.cache_put(:application_metadata_cache, "teiserver_partial_startup_completed", true)
    Central.cache_put(:application_metadata_cache, "teiserver_full_startup_completed", true)

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

    Logger.info("Teiserver startup complete, took #{time_taken}ms")
  end
end
