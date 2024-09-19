defmodule Teiserver.Coordinator.RikerssMemes do
  @moduledoc false
  alias Teiserver.{Account, Battle}
  alias Teiserver.Lobby.{ChatLib}
  alias Teiserver.Data.Types, as: T

  @meme_list ~w(ticks poor rich crazy undo deathmatch)

  @crazy_multiplier_opts ~w(0.3 0.5 0.7 1 1 1 1 1 1 1 1.5 2 4)
  @crazy_multiplier_opts_middler ~w(0.5 0.7 1 1 1 1 1 1 1 1.5 2)
  @crazy_multiplier_opts_positive ~w(1 1 1 1 1.5 2)

  @spec handle_meme(String.t(), T.userid(), map()) :: [String.t()]
  def handle_meme("ticks", senderid, %{lobby_id: lobby_id} = _state) do
    sender = Account.get_user_by_id(senderid)

    labs =
      ~w(armaap armalab armap armavp armhp armshltx armvp armamsub armasy armfhp armplat armshltxuw armsy)

    defences = ~w(armmg armllt armbeamer armhlt arm armdrag armclaw armguard armjuno)
    units = ~w(armham armjeth armpw armrectr armrock armwar)

    cortex =
      ~w(coraap coralab corap coravp corgant corhp corlab corvp corllt corfhp corsy corjuno corhllt corhlt)

    Battle.set_modoptions(lobby_id, %{
      "game/modoptions/map_waterislava" => "1"
    })

    Battle.disable_units(lobby_id, labs ++ defences ++ units ++ cortex)

    [
      "#{sender.name} has enabled the Ticks meme. In this game the only fighting unit you will be able to build will be ticks."
    ]
  end

  def handle_meme("deathmatch", senderid, %{lobby_id: lobby_id} = _state) do
    sender = Account.get_user_by_id(senderid)

    Battle.set_modoptions(lobby_id, %{
      "game/modoptions/startmetal" => "35000",
      "game/modoptions/startenergy" => "1000",
      "game/modoptions/multiplier_maxvelocity" => "1.5",
      "game/modoptions/multiplier_buildpower" => "1.5",
      "game/modoptions/multiplier_weapondamage" => "1.5"
    })

    antinukes = ~w(armamd corfmd armscab cormabm armcarry corcarry)

    Battle.disable_units(lobby_id, antinukes)

    [
      "#{sender.name} has enabled the Deathmatch meme. You start with a 35k metal, 1k energy, everything builds fast, runs fast and hits hard. Beware, anti-nukes are disabled; Good luck Commander."
    ]
  end

  def handle_meme("poor", senderid, %{lobby_id: lobby_id} = _state) do
    sender = Account.get_user_by_id(senderid)
    Battle.set_modoption(lobby_id, "game/modoptions/multiplier_resourceincome", "0")

    ["#{sender.name} has enabled the poor meme. Nobody can produce resources."]
  end

  def handle_meme("rich", senderid, %{lobby_id: lobby_id} = _state) do
    sender = Account.get_user_by_id(senderid)

    Battle.set_modoptions(lobby_id, %{
      "game/modoptions/startmetal" => "100000000",
      "game/modoptions/startenergy" => "100000000",
      "game/modoptions/multiplier_resourceincome" => "1000"
    })

    ["#{sender.name} has enabled the rich meme. Everybody has insane amounts of resources."]
  end

  def handle_meme("crazy", senderid, %{lobby_id: lobby_id} = _state) do
    sender = Account.get_user_by_id(senderid)
    undo_memes(lobby_id)
    :timer.sleep(100)

    new_options = %{
      "game/modoptions/startmetal" => Enum.random(~w(500 750 1000 1500 2500 5000 10000 100000)),
      "game/modoptions/startenergy" =>
        Enum.random(~w(750 1000 1500 2500 5000 10000 100000 500000)),
      "game/modoptions/multiplier_resourceincome" =>
        Enum.random(~w(0.1 0.25 0.5 0.75 1 1.5 2 5 10)),
      "game/modoptions/maxunits" => Enum.random(~w(100 500 1000 2000 2000 2000 2000)),
      "game/modoptions/norushtimer" => Enum.random(~w(0 0 0 0 0 0 0 0 0 1 2 3 4 5 8 10 10)),
      "game/modoptions/map_waterlevel" => Enum.random(~w(-200 -100 -50 0 0 0 0 50 100 200)),
      "game/modoptions/lootboxes" => Enum.random(~w(scav_only scav_only scav_only enabled)),
      "game/modoptions/lootboxes_density" => Enum.random(~w(veryrare rarer normal normal normal)),
      "game/modoptions/teamcolors_anonymous_mode" =>
        Enum.random(~w(disabled disabled disabled disco)),
      "game/modoptions/multiplier_shieldpower" => Enum.random(~w(1 1 1 2 3 4)),
      "game/modoptions/disable_fogofwar" => Enum.random(~w(0 0 0 1)),
      "game/modoptions/assistdronesenabled" =>
        Enum.random(~w(disabled disabled disabled enabled)),
      "game/modoptions/assistdronescount" => Enum.random(~w(2 4 8 10 16)),
      "game/modoptions/experimentalextraunits" => Enum.random(~w(0 0 0 1)),
      "game/modoptions/multiplier_turnrate" => Enum.random(@crazy_multiplier_opts),
      "game/modoptions/multiplier_builddistance" => Enum.random(@crazy_multiplier_opts_positive),
      "game/modoptions/multiplier_weaponrange" => Enum.random(@crazy_multiplier_opts),
      "game/modoptions/multiplier_weapondamage" => Enum.random(@crazy_multiplier_opts),
      "game/modoptions/multiplier_buildpower" => Enum.random(@crazy_multiplier_opts),
      "game/modoptions/multiplier_maxvelocity" => Enum.random(@crazy_multiplier_opts_middler),
      "game/modoptions/multiplier_losrange" => Enum.random(@crazy_multiplier_opts),
      "game/modoptions/multiplier_radarrange" => Enum.random(@crazy_multiplier_opts)
    }

    # Toggle default for some options based on others
    # Assist dronse
    new_options =
      if new_options["game/modoptions/assistdronesenabled"] != "enabled" do
        Map.put(new_options, "game/modoptions/assistdronescount", "10")
      else
        new_options
      end

    Battle.set_modoptions(lobby_id, new_options)

    [
      "#{sender.name} has enabled the crazy meme. We've rolled some dice on a bunch of stuff and hopefully it'll make for a fun game."
    ]
  end

  def handle_meme("undo", _senderid, %{lobby_id: lobby_id} = _state) do
    undo_memes(lobby_id)

    [
      "Meme modes have been (as best as possible) undone. Please check the game settings still in place to ensure they have all been removed."
    ]
  end

  def handle_meme(_meme, senderid, state) do
    ChatLib.sayprivateex(
      state.coordinator_id,
      senderid,
      "That's not a valid meme. The memes are #{Enum.join(@meme_list, ", ")}",
      state.lobby_id
    )

    []
  end

  def undo_memes(lobby_id) do
    Battle.enable_all_units(lobby_id)

    new_options = %{
      "game/modoptions/startmetal" => "1000",
      "game/modoptions/startenergy" => "1000",
      "game/modoptions/multiplier_resourceincome" => "1",
      "game/modoptions/maxunits" => "2000",
      "game/modoptions/norushtimer" => "0",
      "game/modoptions/map_waterlevel" => "0",
      "game/modoptions/lootboxes" => "scav_only",
      "game/modoptions/lootboxes_density" => "normal",
      "game/modoptions/teamcolors_anonymous_mode" => "disabled",
      "game/modoptions/multiplier_shieldpower" => "1",
      "game/modoptions/disable_fogofwar" => "0",
      "game/modoptions/assistdronesenabled" => "disabled",
      "game/modoptions/assistdronescount" => "10",
      "game/modoptions/experimentalextraunits" => "0",
      "game/modoptions/multiplier_turnrate" => "1",
      "game/modoptions/multiplier_builddistance" => "1",
      "game/modoptions/multiplier_weaponrange" => "1",
      "game/modoptions/multiplier_weapondamage" => "1",
      "game/modoptions/multiplier_buildpower" => "1",
      "game/modoptions/multiplier_maxvelocity" => "1",
      "game/modoptions/multiplier_losrange" => "1",
      "game/modoptions/multiplier_radarrange" => "1"
    }

    Battle.set_modoptions(lobby_id, new_options)
  end
end
