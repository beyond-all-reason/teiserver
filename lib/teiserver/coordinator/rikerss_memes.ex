defmodule Teiserver.Coordinator.RikerssMemes do
  @moduledoc false
  alias Teiserver.{User}
  alias Teiserver.Battle.{Lobby, LobbyChat}
  alias Teiserver.Data.Types, as: T

  @meme_list ~w(ticks greenfields poor rich hardt1 crazy undo)

  @spec handle_meme(String.t(), T.userid(), map()) :: [String.t()]
  def handle_meme("ticks", senderid, %{lobby_id: lobby_id} = _state) do
    sender = User.get_user_by_id(senderid)

    labs = ~w(armaap armalab armap armavp armhp armshltx armvp armamsub armasy armfhp armplat armshltxuw armsy)
    defences = ~w(armmg armllt armbeamer armhlt arm armdrag armclaw armguard armjuno)
    units = ~w(armham armjeth armpw armrectr armrock armwar)

    cortex = ~w(coraap coralab corap coravp corgant corhp corlab corvp corllt corfhp corsy corjuno corhllt corhlt)
    Lobby.disable_units(lobby_id, labs ++ defences ++ units ++ cortex)

    ["#{sender.name} has enabled the Ticks meme. In this game the only fighting unit you will be able to build will be ticks. It is highly inadvisable to play Cortex."]
  end

  def handle_meme("greenfields", senderid, %{lobby_id: lobby_id} = _state) do
    sender = User.get_user_by_id(senderid)

    Lobby.disable_units(lobby_id, ~w(armmex armamex armmoho cormex corexp cormexp cormoho))

    ["#{sender.name} has enabled the Greenfield meme. Metal extractors are disabled."]
  end

  def handle_meme("poor", senderid, %{lobby_id: lobby_id} = _state) do
    sender = User.get_user_by_id(senderid)
    battle = Lobby.get_lobby(lobby_id)
    new_tags = Map.merge(battle.tags, %{
      "game/modoptions/resourceincomemultiplier" => "0",
    })
    Lobby.set_script_tags(lobby_id, new_tags)

    ["#{sender.name} has enabled the poor meme. Nobody can produce resources."]
  end

  def handle_meme("rich", senderid, %{lobby_id: lobby_id} = _state) do
    sender = User.get_user_by_id(senderid)
    battle = Lobby.get_lobby(lobby_id)
    new_tags = Map.merge(battle.tags, %{
      "game/modoptions/startmetal" => "100000000",
      "game/modoptions/startenergy" => "100000000",
      "game/modoptions/resourceincomemultiplier" => "1000",
    })
    Lobby.set_script_tags(lobby_id, new_tags)

    ["#{sender.name} has enabled the rich meme. Everybody has insane amounts of resources."]
  end

  def handle_meme("hardt1", senderid, %{lobby_id: lobby_id} = _state) do
    sender = User.get_user_by_id(senderid)

    armada = ~w(armfhp armhp armamsub armplat armalab armavp armaap armasy armshltx armshltxuw)
    cortex = ~w(corfhp corhp coaramsub corplat coravp coralab coraap corgantuw corgant corasy)

    Lobby.disable_units(lobby_id, armada ++ cortex)

    ["#{sender.name} has enabled the hard T1 meme. You can only build T1 (Seaplanes and Hovers are T1.5, they are disabled)."]
  end

  def handle_meme("crazy", senderid, %{lobby_id: lobby_id} = _state) do
    sender = User.get_user_by_id(senderid)
    undo_memes(lobby_id)
    :timer.sleep(100)

    battle = Lobby.get_lobby(lobby_id)
    new_tags = Map.merge(battle.tags, %{
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
      "game/modoptions/experimentalradarrange" => Enum.random(~w(0.5 0.75 0.8 1 1 1 1 1 1.5 2)),
      "game/modoptions/disable_fogofwar" => Enum.random(~w(0 0 0 1)),

      "game/modoptions/assistdronesenabled" => Enum.random(~w(scav_only scav_only scav_only enabled)),
      "game/modoptions/assistdronescount" => Enum.random(~w(2 4 8 16)),

      "game/modoptions/experimentalscavuniqueunits" => Enum.random(~w(0 0 0 1)),
      "game/modoptions/experimentallosrange" => Enum.random(~w(0.3 0.4 0.5 0.8 1 1 1 1 1.5)),
    })
    Lobby.set_script_tags(lobby_id, new_tags)

    ["#{sender.name} has enabled the crazy meme. We've rolled some dice on a bunch of stuff and hopefully it'll make for a fun game."]

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
    Lobby.enable_all_units(lobby_id)

    battle = Lobby.get_lobby(lobby_id)
    new_tags = Map.merge(battle.tags, %{
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
      "game/modoptions/experimentalradarrange" => "1",
      "game/modoptions/disable_fogofwar" => "0",

      "game/modoptions/assistdronesenabled" => "scav_only",
      "game/modoptions/assistdronescount" => "4",

      "game/modoptions/experimentalscavuniqueunits" => "0",
      "game/modoptions/experimentallosrange" => "1",
    })
    Lobby.set_script_tags(lobby_id, new_tags)
  end
end
