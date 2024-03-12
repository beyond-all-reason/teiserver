defmodule Barserver.Startup do
  @moduledoc false
  use BarserverWeb, :startup
  require Logger
  alias Phoenix.PubSub

  @spec startup :: :ok
  def startup do
    start_time = System.system_time(:millisecond)

    # Brought over from Central
    Barserver.store_put(
      :application_metadata_cache,
      "random_names_1",
      ~w(serene energised humble auspicious decisive exemplary cheerful determined playful spry springy)
    )

    Barserver.store_put(:application_metadata_cache, "random_names_2", ~w(
      maroon cherry rose ruby
      amber carrot
      lemon beige
      mint lime cadmium
      aqua cerulean
      lavender indigo
      magenta amethyst
    ))

    Barserver.store_put(
      :application_metadata_cache,
      "random_names_3",
      ~w(hamster gerbil cat dog falcon eagle mole fox tiger panda elephant lion cow dove whale dolphin squid dragon snake platypus badger)
    )

    add_permission_set("admin", "debug", ~w(debug))
    add_permission_set("admin", "dev", ~w(developer structure))
    add_permission_set("admin", "admin", ~w(limited full))
    add_permission_set("admin", "report", ~w(show update delete report))
    add_permission_set("admin", "user", ~w(show create update delete report))
    add_permission_set("admin", "group", ~w(show create update delete report config))

    Barserver.Logging.Startup.startup()

    # User Configs
    Barserver.Config.UserConfigTypes.ProfileConfigs.create()
    Barserver.Config.UserConfigTypes.PrivacyConfigs.create()

    # System Configs
    Barserver.Config.SiteConfigTypes.SystemConfigs.create()

    Barserver.BarserverConfigs.teiserver_configs()

    Barserver.Communication.build_text_callback_cache()

    Barserver.LobbyIdServer.start_lobby_id_server()

    Barserver.Tachyon.CommandDispatch.build_dispatch_cache()
    Barserver.Tachyon.Schema.load_schemas()

    Barserver.Lobby.CommandLib.cache_lobby_commands()
    Barserver.Bridge.CommandLib.cache_discord_commands()
    Barserver.Communication.pre_cache_discord_channels()

    # Chat stuff
    Barserver.Account.UserLib.add_report_restriction_types("Chat", [
      "Bridging",
      "Game chat",
      "Room chat",
      "All chat"
    ])

    # Lobby interaction
    Barserver.Account.UserLib.add_report_restriction_types("Game", [
      "Low priority",
      "All lobbies",
      "Login",
      "Permanently banned"
    ])

    Barserver.Account.UserLib.add_report_restriction_types("Other", [
      "Accolades",
      "Boss",
      "Reporting",
      "Renaming",
      "Matchmaking"
    ])

    Barserver.Account.UserLib.add_report_restriction_types("Warnings", [
      "Warning reminder"
    ])

    Barserver.Account.UserLib.add_report_restriction_types("Internal", [
      "Note"
    ])

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
      "Barserver:Updated automod action",
      "Barserver:Automod action enacted",
      "Barserver:De-bridged user",
      "Barserver:Changed user rating",
      "Barserver:Changed user name",
      "Barserver:Smurf merge",
      "Microblog.delete_post",
      "Discord.text_callback"
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

    Barserver.store_put(
      :application_metadata_cache,
      "random_names_3",
      ~w(tick pawn lazarus rocketeer crossbow mace centurion tumbleweed smuggler compass ghost sprinter butler webber platypus hound welder recluse archangel gunslinger sharpshooter umbrella fatboy marauder vanguard razorback titan) ++
        ~w(grunt graverobber aggravator trasher thug bedbug deceiver augur spectre fiend twitcher duck skuttle sumo arbiter manticore termite commando mammoth shiva karganeth catapult behemoth juggernaught)
    )

    Barserver.cache_put(:lists, :rooms, [])
    Barserver.cache_put(:lists, :lobby_policies, [])

    Barserver.Data.Matchmaking.pre_cache_queues()
    Barserver.Game.pre_cache_policies()

    # Add in achievements
    Barserver.Game.GenerateAchievementTypes.perform()

    if Application.get_env(:teiserver, Barserver)[:enable_match_monitor] do
      spawn(fn ->
        :timer.sleep(200)
        Barserver.Battle.start_match_monitor()
      end)
    end

    if Application.get_env(:teiserver, Barserver)[:enable_coordinator_mode] do
      spawn(fn ->
        :timer.sleep(200)
        Barserver.Coordinator.start_coordinator()
        Barserver.Coordinator.AutomodServer.start_automod_server()
      end)
    end

    if Application.get_env(:teiserver, Barserver)[:enable_accolade_mode] do
      spawn(fn ->
        :timer.sleep(200)
        Barserver.Account.AccoladeLib.start_accolade_server()
      end)
    end

    Barserver.cache_put(:application_metadata_cache, "teiserver_partial_startup_completed", true)
    Barserver.cache_put(:application_metadata_cache, "teiserver_full_startup_completed", true)

    Barserver.Account.LoginThrottleServer.startup()

    # Give everything else a chance to have started up
    spawn(fn ->
      :timer.sleep(1000)

      PubSub.broadcast(
        Barserver.PubSub,
        "teiserver_server",
        %{
          channel: "teiserver_server",
          event: :started,
          node: Node.self()
        }
      )
    end)

    time_taken = System.system_time(:millisecond) - start_time

    Barserver.Telemetry.log_complex_server_event(nil, "Server startup", %{
      time_taken_ms: time_taken
    })

    Barserver.cache_put(:application_metadata_cache, :node_startup_datetime, Timex.now())

    Logger.info("Barserver startup complete, took #{time_taken}ms")
  end
end
