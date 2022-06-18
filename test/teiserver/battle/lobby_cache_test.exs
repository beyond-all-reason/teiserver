defmodule Teiserver.Battle.LobbyCacheTest do
  use Central.ServerCase, async: false
  alias Teiserver.Battle.Lobby
  alias Teiserver.Account.ClientLib
  alias Teiserver.Common.PubsubListener
  alias Teiserver.{Battle, Account, Client, Coordinator}
  alias Teiserver.Coordinator.ConsulServer

  import Teiserver.TeiserverTestLib,
    only: [tachyon_auth_setup: 0, _tachyon_send: 2, _tachyon_recv: 1, _tachyon_recv_until: 1]

  setup do
    %{socket: hsocket, user: host} = tachyon_auth_setup()
    %{socket: psocket, user: player} = tachyon_auth_setup()

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

    {:ok, hsocket: hsocket, psocket: psocket, host: host, player: player, lobby_id: lobby_id}
  end

  test "add_user_to_battle", %{lobby_id: lobby_id, player: player} do
    IO.puts ""
    IO.inspect {player.id}
    IO.puts ""

    p_client = Account.get_client_by_id(player.id)
    assert p_client.lobby_id == nil

    Lobby.add_user_to_battle(player.id, lobby_id, "script_password")
    p_client = Account.get_client_by_id(player.id)
    assert p_client.lobby_id == lobby_id
  end
end
