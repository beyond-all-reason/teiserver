defmodule Teiserver.Protocols.Director.CommandsTest do
  use Central.ServerCase, async: false
  alias Teiserver.Battle.BattleLobby
  alias Teiserver.Common.PubsubListener
  alias Teiserver.{Client, Director, User}

  import Teiserver.TeiserverTestLib,
    only: [tachyon_auth_setup: 0, _tachyon_send: 2, _tachyon_recv: 1]

  setup do
    Teiserver.Director.start_director()
    %{socket: hsocket, user: host} = tachyon_auth_setup()
    %{socket: psocket, user: player} = tachyon_auth_setup()

    # User needs to be a moderator (at this time) to start/stop director mode
    User.update_user(%{host | moderator: true})
    Client.refresh_client(host.id)

    battle_data = %{
      cmd: "c.battle.create",
      name: "Director #{:random.uniform(999_999_999)}",
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
    data = %{cmd: "c.battle.create", battle: battle_data}
    _tachyon_send(hsocket, data)
    reply = _tachyon_recv(hsocket)
    battle_id = reply["battle"]["id"]

    BattleLobby.start_director_mode(battle_id)
    listener = PubsubListener.new_listener(["battle_updates:#{battle_id}"])

    # Player needs to be added to the battle
    BattleLobby.add_user_to_battle(player.id, battle_id, "script_password")
    player_client = Client.get_client_by_id(player.id)
    Client.update(%{player_client |
      player: true
    }, :client_updated_battlestatus)

    {:ok, hsocket: hsocket, psocket: psocket, host: host, player: player, battle_id: battle_id, listener: listener}
  end

  test "force-spectator", %{host: host, player: player, hsocket: hsocket} do
    player_client = Client.get_client_by_id(player.id)
    assert player_client.player == true

    data = %{cmd: "c.battle.message", userid: host.id, message: "!force-spectator #{player.name}"}
    _tachyon_send(hsocket, data)

    player_client = Client.get_client_by_id(player.id)
    assert player_client.player == false
  end

  test "kick", %{host: host, player: player, hsocket: hsocket} do
    player_client = Client.get_client_by_id(player.id)
    assert player_client.player == true

    data = %{cmd: "c.battle.message", userid: host.id, message: "!kick #{player.name}"}
    _tachyon_send(hsocket, data)

    player_client = Client.get_client_by_id(player.id)
    assert player_client.battle_id == nil
  end

  test "ban", %{host: host, player: player, hsocket: hsocket} do
    player_client = Client.get_client_by_id(player.id)
    assert player_client.player == true

    data = %{cmd: "c.battle.message", userid: host.id, message: "!ban #{player.name}"}
    _tachyon_send(hsocket, data)

    player_client = Client.get_client_by_id(player.id)
    assert player_client.battle_id == nil
  end
end
