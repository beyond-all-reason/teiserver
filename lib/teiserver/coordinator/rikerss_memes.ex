defmodule Teiserver.Coordinator.RikerssMemes do
  @moduledoc false
  alias Teiserver.{User, Battle}
  alias Teiserver.Battle.{LobbyChat}
  alias Teiserver.Data.Types, as: T

  @meme_list ~w(ticks nodefence greenfields poor rich hardt1 crazy undo)

  @crazy_multiplier_opts ~w(0.3 0.5 0.7 1 1 1 1 1 1 1 1.5 2 4)
  @crazy_multiplier_opts_middler ~w(0.5 0.7 1 1 1 1 1 1 1 1.5 2)

  @spec handle_meme(String.t(), T.userid(), map()) :: [String.t()]
  def handle_meme("ticks", senderid, %{lobby_id: lobby_id} = _state) do
    sender = User.get_user_by_id(senderid)

    labs = ~w(armaap armalab armap armavp armhp armshltx armvp armamsub armasy armfhp armplat armshltxuw armsy)
    defences = ~w(armmg armllt armbeamer armhlt arm armdrag armclaw armguard armjuno)
    units = ~w(armham armjeth armpw armrectr armrock armwar)

    cortex = ~w(coraap coralab corap coravp corgant corhp corlab corvp corllt corfhp corsy corjuno corhllt corhlt)
    Battle.disable_units(lobby_id, labs ++ defences ++ units ++ cortex)

    ["#{sender.name} has enabled the Ticks meme. In this game the only fighting unit you will be able to build will be ticks. It is highly inadvisable to play Cortex."]
  end

  def handle_meme("greenfields", senderid, %{lobby_id: lobby_id} = _state) do
    sender = User.get_user_by_id(senderid)

    Battle.disable_units(lobby_id, ~w(armmex armamex armmoho cormex corexp cormexp cormoho))

    ["#{sender.name} has enabled the Greenfield meme. Metal extractors are disabled."]
  end

  def handle_meme("poor", senderid, %{lobby_id: lobby_id} = _state) do
    sender = User.get_user_by_id(senderid)
    Battle.set_modoption(lobby_id, "game/modoptions/resourceincomemultiplier", "0")

    ["#{sender.name} has enabled the poor meme. Nobody can produce resources."]
  end

  def handle_meme("rich", senderid, %{lobby_id: lobby_id} = _state) do
    sender = User.get_user_by_id(senderid)
    Battle.set_modoptions(lobby_id, %{
      "game/modoptions/startmetal" => "100000000",
      "game/modoptions/startenergy" => "100000000",
      "game/modoptions/resourceincomemultiplier" => "1000",
    })

    ["#{sender.name} has enabled the rich meme. Everybody has insane amounts of resources."]
  end

  def handle_meme("hardt1", senderid, %{lobby_id: lobby_id} = _state) do
    sender = User.get_user_by_id(senderid)

    armada = ~w(armfhp armhp armamsub armplat armalab armavp armaap armasy armshltx armshltxuw)
    cortex = ~w(corfhp corhp coaramsub corplat coravp coralab coraap corgantuw corgant corasy)

    Battle.disable_units(lobby_id, armada ++ cortex)

    ["#{sender.name} has enabled the hard T1 meme. You can only build T1 (Seaplanes and Hovers are T1.5, they are disabled)."]
  end

  def handle_meme("crazy", senderid, %{lobby_id: lobby_id} = _state) do
    sender = User.get_user_by_id(senderid)
    undo_memes(lobby_id)
    :timer.sleep(100)

    new_options = %{
      "game/modoptions/startmetal" => Enum.random(~w(500 750 1000 1500 2500 5000 10000 100000)),
      "game/modoptions/startenergy" => Enum.random(~w(750 1000 1500 2500 5000 10000 100000 500000)),
      "game/modoptions/resourceincomemultiplier" => Enum.random(~w(0.1 0.25 0.5 0.75 1 1.5 2 5 10)),

      "game/modoptions/maxunits" => Enum.random(~w(100 500 1000 2000 2000 2000 2000)),

      "game/modoptions/norushtime" => Enum.random(~w(1 2 3 4 5 8 10 10)),
      "game/modoptions/norushmode" => Enum.random(~w(0 0 0 1)),
      "game/modoptions/map_waterlevel" => Enum.random(~w(-200 -100 -50 0 0 0 0 50 100 200)),
      "game/modoptions/lootboxes" => Enum.random(~w(scav_only scav_only scav_only enabled)),
      "game/modoptions/lootboxes_density" => Enum.random(~w(rarer normal normal normal dense verydense)),
      "game/modoptions/teamcolors_anonymous_mode" => Enum.random(~w(0 0 0 1)),
      "game/modoptions/experimentalshieldpower" => Enum.random(~w(1 1 1 2 3 4)),
      "game/modoptions/disable_fogofwar" => Enum.random(~w(0 0 0 1)),

      "game/modoptions/assistdronesenabled" => Enum.random(~w(scav_only scav_only scav_only enabled)),
      "game/modoptions/assistdronescount" => Enum.random(~w(2 4 8 16)),

      "game/modoptions/experimentalscavuniqueunits" => Enum.random(~w(0 0 0 1)),

      "game/modoptions/multiplier_maxdamage" => Enum.random(@crazy_multiplier_opts),
      "game/modoptions/multiplier_turnrate" => Enum.random(@crazy_multiplier_opts),
      "game/modoptions/multiplier_builddistance" => Enum.random(@crazy_multiplier_opts),
      "game/modoptions/multiplier_weaponrange" => Enum.random(@crazy_multiplier_opts),
      "game/modoptions/multiplier_metalcost" => Enum.random(@crazy_multiplier_opts),
      "game/modoptions/multiplier_energycost" => Enum.random(@crazy_multiplier_opts),
      "game/modoptions/multiplier_buildtimecost" => Enum.random(@crazy_multiplier_opts),
      "game/modoptions/multiplier_weapondamage" => Enum.random(@crazy_multiplier_opts),
      "game/modoptions/multiplier_buildpower" => Enum.random(@crazy_multiplier_opts),
      "game/modoptions/multiplier_maxvelocity" => Enum.random(@crazy_multiplier_opts_middler),
      "game/modoptions/multiplier_losrange" => Enum.random(@crazy_multiplier_opts),
      "game/modoptions/multiplier_radarrange" => Enum.random(@crazy_multiplier_opts),
    }

    # Toggle default for some options based on others
    # Assist dronse
    new_options = if new_options["game/modoptions/assistdronesenabled"] != "enabled" do
      Map.put(new_options, "game/modoptions/assistdronescount", "8")
    else
      new_options
    end

    Battle.set_modoptions(lobby_id, new_options)

    ["#{sender.name} has enabled the crazy meme. We've rolled some dice on a bunch of stuff and hopefully it'll make for a fun game."]

  end

  def handle_meme("nodefence", senderid, %{lobby_id: lobby_id} = _state) do
    sender = User.get_user_by_id(senderid)

    armada_defences = ~w(armamb armamd armanni armbeamer armbrtha armclaw armemp armguard armhlt armjuno armmg armpb armsilo armvulc armatl armdl armfhlt armfrt armgplat armkraken armptl armtl)
    armada_aa = ~w(armferret armflak armmercury armrl armfflak armfrock armcir)
    cortex_defences =  ~w(corbhmth corbuzz cordoom corexp corfmd corhllt corhlt corjuno cormaw cormexp corpun corsilo cortoast cortron corvipe coratl cordl corfdoom corfhlt corfrock corfrt corgplat corptl cortl corint)
    cortex_aa = ~w(corerad corflak cormadsam corrl corscreamer corenaa)
    scavt3 = ~w(armannit3 cordoomt3 armbotrail armminivulc corhllllt corminibuzz corscavdrag corscavdtf corscavdtl corscavdtm)

    unit_list = armada_defences ++ armada_aa ++ cortex_defences ++ cortex_aa ++ scavt3

    scav_units = unit_list
      |> Enum.map(fn unit -> "#{unit}_scav" end)

    Battle.disable_units(lobby_id, unit_list ++ scav_units)

    ["#{sender.name} has enabled the No defence meme. In this game you will not be able to create any defences; good luck!"]
  end

  def handle_meme("undo", _senderid, %{lobby_id: lobby_id} = _state) do
    undo_memes(lobby_id)

    ["Meme modes have been (as best as possible) undone. Please check the game settings still in place to ensure they have all been removed."]
  end

  def handle_meme(_meme, senderid, state) do
    LobbyChat.sayprivateex(state.coordinator_id, senderid, "That's not a valid meme. The memes are #{Enum.join(@meme_list, ", ")}", state.lobby_id)
    []
  end

  def undo_memes(lobby_id) do
    Battle.enable_all_units(lobby_id)

    new_options = %{
      "game/modoptions/startmetal" => "1000",
      "game/modoptions/startenergy" => "1000",
      "game/modoptions/resourceincomemultiplier" => "1",

      "game/modoptions/maxunits" => "2000",

      "game/modoptions/norushtime" => "10",
      "game/modoptions/norushmode" => "0",
      "game/modoptions/map_waterlevel" => "0",
      "game/modoptions/lootboxes" => "scav_only",
      "game/modoptions/lootboxes_density" => "normal",
      "game/modoptions/teamcolors_anonymous_mode" => "0",
      "game/modoptions/experimentalshieldpower" => "1",
      "game/modoptions/disable_fogofwar" => "0",

      "game/modoptions/assistdronesenabled" => "scav_only",
      "game/modoptions/assistdronescount" => "4",

      "game/modoptions/experimentalscavuniqueunits" => "0",

      "game/modoptions/multiplier_maxdamage" => "1",
      "game/modoptions/multiplier_turnrate" => "1",
      "game/modoptions/multiplier_builddistance" => "1",
      "game/modoptions/multiplier_weaponrange" => "1",
      "game/modoptions/multiplier_metalcost" => "1",
      "game/modoptions/multiplier_energycost" => "1",
      "game/modoptions/multiplier_buildtimecost" => "1",
      "game/modoptions/multiplier_weapondamage" => "1",
      "game/modoptions/multiplier_buildpower" => "1",
      "game/modoptions/multiplier_maxvelocity" => "1",
      "game/modoptions/multiplier_losrange" => "1",
      "game/modoptions/multiplier_radarrange" => "1",
    }
    Battle.set_modoptions(lobby_id, new_options)
  end
end
