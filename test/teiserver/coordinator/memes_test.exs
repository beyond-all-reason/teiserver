defmodule Teiserver.Coordinator.MemesTest do
  use Central.ServerCase, async: false
  alias Teiserver.Battle.Lobby
  alias Teiserver.Account.ClientLib
  alias Teiserver.{User, Client, Coordinator}

  import Teiserver.TeiserverTestLib,
    only: [tachyon_auth_setup: 0, _tachyon_send: 2, _tachyon_recv: 1, _tachyon_recv_until: 1]

  setup do
    Coordinator.start_coordinator()
    %{socket: hsocket, user: host} = tachyon_auth_setup()
    %{socket: psocket, user: player} = tachyon_auth_setup()

    # User needs to be a moderator (at this time) to start/stop Coordinator mode
    User.update_user(%{host | moderator: true})
    ClientLib.refresh_client(host.id)

    lobby_data = %{
      cmd: "c.lobby.create",
      name: "Coordinator #{:rand.uniform(999_999_999)}",
      nattype: "none",
      port: 1234,
      game_hash: "string_of_characters",
      map_hash: "string_of_characters",
      map_name: "koom valley",
      game_name: "BAR",
      engine_name: "spring-105",
      engine_version: "105.1.2.3",
      settings: %{
        max_players: 12
      }
    }
    data = %{cmd: "c.lobby.create", lobby: lobby_data}
    _tachyon_send(hsocket, data)
    [reply] = _tachyon_recv(hsocket)
    lobby_id = reply["lobby"]["id"]

    # Player needs to be added to the battle
    Lobby.add_user_to_battle(player.id, lobby_id, "script_password")
    player_client = Client.get_client_by_id(player.id)
    Client.update(%{player_client |
      player: true
    }, :client_updated_battlestatus)

    # Add user message
    _tachyon_recv_until(hsocket)

    # Battlestatus message
    _tachyon_recv_until(hsocket)

    {:ok, hsocket: hsocket, psocket: psocket, host: host, player: player, lobby_id: lobby_id}
  end

  test "non-meme", %{hsocket: hsocket} do
    _tachyon_send(hsocket, %{cmd: "c.lobby.message", message: "$meme not_a_meme"})
    [reply] = _tachyon_recv(hsocket)
    assert reply == %{
      "cmd" => "s.lobby.received_lobby_direct_announce",
      "message" => "That's not a valid meme. The memes are ticks, nodefence, greenfields, poor, rich, hardt1, crazy, undo",
      "sender_id" => Coordinator.get_coordinator_userid()
    }
  end

  test "ticks", %{lobby_id: lobby_id, hsocket: hsocket} do
    _tachyon_send(hsocket, %{cmd: "c.lobby.message", message: "$meme ticks"})
    [reply] = _tachyon_recv(hsocket)
    assert reply["cmd"] == "s.lobby.updated"
    assert match?(%{
      "id" => ^lobby_id,
      "disabled_units" => ~w(armaap armalab armap armavp armhp armshltx armvp armamsub armasy armfhp armplat armshltxuw armsy armmg armllt armbeamer armhlt arm armdrag armclaw armguard armjuno armham armjeth armpw armrectr armrock armwar coraap coralab corap coravp corgant corhp corlab corvp corllt corfhp corsy corjuno corhllt corhlt),
    }, reply["lobby"])
  end

  test "greenfields", %{lobby_id: lobby_id, hsocket: hsocket} do
    _tachyon_send(hsocket, %{cmd: "c.lobby.message", message: "$meme greenfields"})
    [reply] = _tachyon_recv(hsocket)
    assert reply["cmd"] == "s.lobby.updated"
    assert match?(%{
      "id" => ^lobby_id,
      "disabled_units" => ~w(armmex armamex armmoho cormex corexp cormexp cormoho),
    }, reply["lobby"])
  end

  test "poor", %{lobby_id: lobby_id, hsocket: hsocket} do
    _tachyon_send(hsocket, %{cmd: "c.lobby.message", message: "$meme poor"})
    [reply] = _tachyon_recv(hsocket)
    assert reply["cmd"] == "s.lobby.updated"
    assert match?(%{
      "id" => ^lobby_id,
      "disabled_units" => [],
      "tags" => %{
        "game/modoptions/resourceincomemultiplier" => "0"
      },
    }, reply["lobby"])
  end

  test "rich", %{lobby_id: lobby_id, hsocket: hsocket} do
    _tachyon_send(hsocket, %{cmd: "c.lobby.message", message: "$meme rich"})
    [reply] = _tachyon_recv(hsocket)
    assert reply["cmd"] == "s.lobby.updated"
    assert match?(%{
      "id" => ^lobby_id,
      "disabled_units" => [],
      "tags" => %{
        "game/modoptions/resourceincomemultiplier" => "1000",
        "game/modoptions/startenergy" => "100000000",
        "game/modoptions/startmetal" => "100000000",
      },
    }, reply["lobby"])
  end

  test "hardt1", %{lobby_id: lobby_id, hsocket: hsocket} do
    _tachyon_send(hsocket, %{cmd: "c.lobby.message", message: "$meme hardt1"})
    [reply] = _tachyon_recv(hsocket)
    assert reply["cmd"] == "s.lobby.updated"
    assert match?(%{
      "id" => ^lobby_id,
      "disabled_units" => ~w(armfhp armhp armamsub armplat armalab armavp armaap armasy armshltx armshltxuw corfhp corhp coaramsub corplat coravp coralab coraap corgantuw corgant corasy),
    }, reply["lobby"])
  end

  test "crazy", %{lobby_id: lobby_id, hsocket: hsocket} do
    _tachyon_send(hsocket, %{cmd: "c.lobby.message", message: "$meme crazy"})
    [reply] = _tachyon_recv(hsocket)
    assert reply["cmd"] == "s.lobby.updated"
    assert match?(%{
      "id" => ^lobby_id,
    }, reply["lobby"])
  end

  test "undo", %{lobby_id: lobby_id, hsocket: hsocket} do
    _tachyon_send(hsocket, %{cmd: "c.lobby.message", message: "$meme ticks"})
    [reply] = _tachyon_recv(hsocket)
    assert reply["cmd"] == "s.lobby.updated"
    assert match?(%{
      "id" => ^lobby_id,
      "disabled_units" => ~w(armaap armalab armap armavp armhp armshltx armvp armamsub armasy armfhp armplat armshltxuw armsy armmg armllt armbeamer armhlt arm armdrag armclaw armguard armjuno armham armjeth armpw armrectr armrock armwar coraap coralab corap coravp corgant corhp corlab corvp corllt corfhp corsy corjuno corhllt corhlt),
    }, reply["lobby"])

    _tachyon_send(hsocket, %{cmd: "c.lobby.message", message: "$meme undo"})
    [reply] = _tachyon_recv(hsocket)
    assert reply["cmd"] == "s.lobby.updated"
    assert match?(%{
      "id" => ^lobby_id,
      "disabled_units" => [],
    }, reply["lobby"])
  end
end
