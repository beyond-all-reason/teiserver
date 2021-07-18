defmodule Teiserver.Coordinator.BlacklistTest do
  use Central.ServerCase, async: false
  alias Teiserver.Battle.BattleLobby
  alias Teiserver.Common.PubsubListener
  alias Teiserver.{Client, User}

  import Teiserver.TeiserverTestLib,
    only: [tachyon_auth_setup: 0, _tachyon_send: 2, _tachyon_recv: 1]

  setup do
    Teiserver.Coordinator.start_coordinator()
    %{socket: hsocket, user: host} = tachyon_auth_setup()
    %{socket: psocket, user: player} = tachyon_auth_setup()

    # User needs to be a moderator (at this time) to start/stop Coordinator mode
    User.update_user(%{host | moderator: true})
    Client.refresh_client(host.id)

    battle_data = %{
      cmd: "c.battle.create",
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
    data = %{cmd: "c.battle.create", battle: battle_data}
    _tachyon_send(hsocket, data)
    reply = _tachyon_recv(hsocket)
    battle_id = reply["battle"]["id"]

    BattleLobby.start_coordinator_mode(battle_id)
    listener = PubsubListener.new_listener(["legacy_battle_updates:#{battle_id}"])

    # Player needs to be added to the battle
    BattleLobby.force_add_user_to_battle(player.id, battle_id)
    :timer.sleep(100)
    player_client = Client.get_client_by_id(player.id)
    Client.update(%{player_client |
      player: true
    }, :client_updated_battlestatus)

    {:ok, hsocket: hsocket, psocket: psocket, host: host, player: player, battle_id: battle_id, listener: listener}
  end

  test "blacklist to spectator", %{host: host, player: player, hsocket: hsocket, psocket: psocket, battle_id: battle_id} do
    player_client = Client.get_client_by_id(player.id)
    assert player_client.player == true
    assert player_client.battle_id == battle_id

    # Blacklist them to spectator
    data = %{cmd: "c.battle.message", userid: host.id, message: "!blacklist ##{player.id} spectator"}
    _tachyon_send(hsocket, data)

    # Check it's worked
    player_client = Client.get_client_by_id(player.id)
    assert player_client.player == false
    assert player_client.battle_id == battle_id

    # Try to change it
    data = %{cmd: "c.battle.update_status", player: true}
    _tachyon_send(psocket, data)

    # Still working
    player_client = Client.get_client_by_id(player.id)
    assert player_client.player == false
    assert player_client.battle_id == battle_id

    # Un-blacklist them
    data = %{cmd: "c.battle.message", userid: host.id, message: "!blacklist ##{player.id} player"}
    _tachyon_send(hsocket, data)

    # Try to change it
    data = %{cmd: "c.battle.update_status", player: true}
    _tachyon_send(psocket, data)

    # Back to being allowed
    player_client = Client.get_client_by_id(player.id)
    assert player_client.player == true
    assert player_client.battle_id == battle_id
  end
end
