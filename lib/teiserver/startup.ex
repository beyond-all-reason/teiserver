defmodule Teiserver.Startup do
  @moduledoc false
  use TeiserverWeb, :startup
  require Logger
  alias Phoenix.PubSub

  @spec startup :: :ok
  def startup do
    start_time = System.system_time(:millisecond)

    # Brought over from Central
    Teiserver.store_put(
      :application_metadata_cache,
      "random_names_1",
      ~w(serene energised humble auspicious decisive exemplary cheerful determined playful spry springy)
    )

    Teiserver.store_put(:application_metadata_cache, "random_names_2", ~w(
      maroon cherry rose ruby
      amber carrot
      lemon beige
      mint lime cadmium
      aqua cerulean
      lavender indigo
      magenta amethyst
    ))

    Teiserver.store_put(
      :application_metadata_cache,
      "random_names_3",
      ~w(hamster gerbil cat dog falcon eagle mole fox tiger panda elephant lion cow dove whale dolphin squid dragon snake platypus badger)
    )

    Teiserver.Logging.Startup.startup()

    # User Configs
    Teiserver.Config.UserConfigTypes.ProfileConfigs.create()
    Teiserver.Config.UserConfigTypes.PrivacyConfigs.create()

    # System Configs
    Teiserver.Config.SiteConfigTypes.SystemConfigs.create()

    Teiserver.TeiserverConfigs.teiserver_configs()

    Teiserver.Communication.build_text_callback_cache()

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

    Teiserver.store_put(
      :application_metadata_cache,
      "random_names_3",
      ~w(tick pawn lazarus rocketeer crossbow mace centurion tumbleweed smuggler compass ghost sprinter butler webber platypus hound welder recluse archangel gunslinger sharpshooter umbrella fatboy marauder vanguard razorback titan) ++
        ~w(grunt graverobber aggravator trasher thug bedbug deceiver augur spectre fiend twitcher duck skuttle sumo arbiter manticore termite commando mammoth shiva karganeth catapult behemoth juggernaught)
    )

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
