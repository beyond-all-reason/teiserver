defmodule Teiserver.Coordinator.CommandsTest do
  use Central.ServerCase, async: false
  alias Teiserver.Battle.Lobby
  alias Teiserver.Common.PubsubListener
  alias Teiserver.{Client, User}
  alias Teiserver.Coordinator

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

    Lobby.start_coordinator_mode(battle_id)
    listener = PubsubListener.new_listener(["legacy_battle_updates:#{battle_id}"])

    # Player needs to be added to the battle
    Lobby.add_user_to_battle(player.id, battle_id, "script_password")
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

  test "kick by name", %{host: host, player: player, hsocket: hsocket} do
    player_client = Client.get_client_by_id(player.id)
    assert player_client.player == true

    data = %{cmd: "c.battle.message", userid: host.id, message: "!kick #{player.name}"}
    _tachyon_send(hsocket, data)

    player_client = Client.get_client_by_id(player.id)
    assert player_client.battle_id == nil
  end

  test "kick by id", %{host: host, player: player, hsocket: hsocket} do
    player_client = Client.get_client_by_id(player.id)
    assert player_client.player == true

    data = %{cmd: "c.battle.message", userid: host.id, message: "!kick ##{player.id}"}
    _tachyon_send(hsocket, data)

    player_client = Client.get_client_by_id(player.id)
    assert player_client.battle_id == nil
  end

  test "ban by name", %{host: host, player: player, hsocket: hsocket} do
    player_client = Client.get_client_by_id(player.id)
    assert player_client.player == true

    data = %{cmd: "c.battle.message", userid: host.id, message: "!ban #{player.name}"}
    _tachyon_send(hsocket, data)

    player_client = Client.get_client_by_id(player.id)
    assert player_client.battle_id == nil
  end

  test "ban by partial name", %{host: host, player: player, hsocket: hsocket} do
    player_client = Client.get_client_by_id(player.id)
    assert player_client.player == true

    data = %{cmd: "c.battle.message", userid: host.id, message: "!ban #{player.name |> String.slice(0, 17)}"}
    _tachyon_send(hsocket, data)

    player_client = Client.get_client_by_id(player.id)
    assert player_client.battle_id == nil
  end

  test "blacklist", %{battle_id: battle_id, host: host, player: player, hsocket: hsocket} do
    blacklist = Coordinator.call_consul(battle_id, {:get, :blacklist})
    assert blacklist == %{}

    data = %{cmd: "c.battle.message", userid: host.id, message: "!blacklist ##{player.id} banned"}
    _tachyon_send(hsocket, data)
    blacklist = Coordinator.call_consul(battle_id, {:get, :blacklist})
    assert blacklist == %{
      player.id => :banned
    }

    data = %{cmd: "c.battle.message", userid: host.id, message: "!blacklist ##{player.id} spectator"}
    _tachyon_send(hsocket, data)
    blacklist = Coordinator.call_consul(battle_id, {:get, :blacklist})
    assert blacklist == %{
      player.id => :spectator
    }

    data = %{cmd: "c.battle.message", userid: host.id, message: "!blacklist ##{player.id} player"}
    _tachyon_send(hsocket, data)
    blacklist = Coordinator.call_consul(battle_id, {:get, :blacklist})
    assert blacklist == %{}
  end

  test "whitelist", %{battle_id: battle_id, host: host, player: player, hsocket: hsocket} do
    whitelist = Coordinator.call_consul(battle_id, {:get, :whitelist})
    assert whitelist == %{
      :default => :player
    }

    data = %{cmd: "c.battle.message", userid: host.id, message: "!whitelist ##{player.id} spectator"}
    _tachyon_send(hsocket, data)
    whitelist = Coordinator.call_consul(battle_id, {:get, :whitelist})
    assert whitelist == %{
      player.id => :spectator,
      :default => :player
    }

    data = %{cmd: "c.battle.message", userid: host.id, message: "!whitelist ##{player.id} player"}
    _tachyon_send(hsocket, data)
    whitelist = Coordinator.call_consul(battle_id, {:get, :whitelist})
    assert whitelist == %{
      player.id => :player,
      :default => :player
    }

    data = %{cmd: "c.battle.message", userid: host.id, message: "!whitelist ##{player.id} banned"}
    _tachyon_send(hsocket, data)
    whitelist = Coordinator.call_consul(battle_id, {:get, :whitelist})
    assert whitelist == %{
      :default => :player
    }

    data = %{cmd: "c.battle.message", userid: host.id, message: "!whitelist default banned"}
    _tachyon_send(hsocket, data)
    whitelist = Coordinator.call_consul(battle_id, {:get, :whitelist})
    assert whitelist == %{
      :default => :banned
    }
  end

  test "whitelist player-as-is", %{battle_id: battle_id, player: player1, host: host, hsocket: hsocket} do
    %{user: player2} = tachyon_auth_setup()
    %{user: _player3} = tachyon_auth_setup()

    # Add player2 to the battle but as a spectator
    # player3 is not touched, they should not appear on this list
    Lobby.add_user_to_battle(player2.id, battle_id, "script_password")
    player_client = Client.get_client_by_id(player2.id)
    Client.update(%{player_client |
      player: false
    }, :client_updated_battlestatus)

    data = %{cmd: "c.battle.message", userid: host.id, message: "!whitelist player-as-is"}
    _tachyon_send(hsocket, data)

    whitelist = Coordinator.call_consul(battle_id, {:get, :whitelist})
    assert whitelist == %{
      player1.id => :player,
      player2.id => :spectator,
      :default => :spectator
    }
  end

  test "status", %{battle_id: battle_id, host: host, hsocket: hsocket} do
    data = %{cmd: "c.battle.message", userid: host.id, message: "!status"}
    _tachyon_send(hsocket, data)

    reply = _tachyon_recv(hsocket)
    assert reply["cmd"] == "s.communication.direct_message"
    assert reply["sender"] == Coordinator.get_coordinator_userid()
    assert reply["message"] == ["Status for battle ##{battle_id}", "Gatekeeper: blacklist"]
  end

  test "help", %{host: host, hsocket: hsocket} do
    data = %{cmd: "c.battle.message", userid: host.id, message: "!help"}
    _tachyon_send(hsocket, data)

    reply = _tachyon_recv(hsocket)
    assert reply["cmd"] == "s.communication.direct_message"
    assert reply["sender"] == Coordinator.get_coordinator_userid()
    assert reply["message"] == ["Command list can currently be found at https://github.com/beyond-all-reason/teiserver/blob/master/lib/teiserver/coordinator/coordinator_lib.ex"]
  end

  test "pull user", %{battle_id: battle_id, host: host, hsocket: hsocket} do
    %{user: player2, socket: psocket} = tachyon_auth_setup()

    data = %{cmd: "c.battle.message", userid: host.id, message: "!pull ##{player2.id}"}
    _tachyon_send(hsocket, data)

    reply = _tachyon_recv(psocket)
    assert reply["cmd"] == "s.battle.join_response"
    assert reply["battle"]["id"] == battle_id
  end

  test "test passthrough", %{battle_id: battle_id, host: host, hsocket: hsocket, listener: listener} do
    data = %{cmd: "c.battle.message", userid: host.id, message: "!non-existing command"}
    _tachyon_send(hsocket, data)

    messages = PubsubListener.get(listener)
    assert messages == [{:battle_updated, battle_id, {host.id, "!non-existing command", battle_id}, :say}]

    reply = _tachyon_recv(hsocket)
    assert reply == :timeout
  end
end
