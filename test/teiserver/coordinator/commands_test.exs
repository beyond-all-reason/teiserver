defmodule Teiserver.Coordinator.CommandsTest do
  use Central.ServerCase, async: false
  alias Teiserver.Battle.Lobby
  alias Teiserver.Common.PubsubListener
  alias Teiserver.{User, Client, Coordinator}
  alias Teiserver.Account.UserCache

  import Teiserver.TeiserverTestLib,
    only: [tachyon_auth_setup: 0, _tachyon_send: 2, _tachyon_recv: 1]

  setup do
    Teiserver.Coordinator.start_coordinator()
    %{socket: hsocket, user: host} = tachyon_auth_setup()
    %{socket: psocket, user: player} = tachyon_auth_setup()

    # User needs to be a moderator (at this time) to start/stop Coordinator mode
    UserCache.update_user(%{host | moderator: true})
    Client.refresh_client(host.id)

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
    reply = _tachyon_recv(hsocket)
    lobby_id = reply["lobby"]["id"]

    Lobby.start_coordinator_mode(lobby_id)
    listener = PubsubListener.new_listener(["legacy_battle_updates:#{lobby_id}"])

    # Player needs to be added to the battle
    Lobby.add_user_to_battle(player.id, lobby_id, "script_password")
    player_client = Client.get_client_by_id(player.id)
    Client.update(%{player_client |
      player: true
    }, :client_updated_battlestatus)

    {:ok, hsocket: hsocket, psocket: psocket, host: host, player: player, lobby_id: lobby_id, listener: listener}
  end

  test "force-spectator", %{host: host, player: player, hsocket: hsocket} do
    player_client = Client.get_client_by_id(player.id)
    assert player_client.player == true

    data = %{cmd: "c.lobby.message", userid: host.id, message: "!force force-spectator #{player.name}"}
    _tachyon_send(hsocket, data)

    player_client = Client.get_client_by_id(player.id)
    assert player_client.player == false
  end

  test "kick by name", %{host: host, player: player, hsocket: hsocket} do
    player_client = Client.get_client_by_id(player.id)
    assert player_client.player == true

    data = %{cmd: "c.lobby.message", userid: host.id, message: "!force kick #{player.name}"}
    _tachyon_send(hsocket, data)

    player_client = Client.get_client_by_id(player.id)
    assert player_client.lobby_id == nil
  end

  test "kick by id", %{host: host, player: player, hsocket: hsocket} do
    player_client = Client.get_client_by_id(player.id)
    assert player_client.player == true

    data = %{cmd: "c.lobby.message", userid: host.id, message: "!force kick ##{player.id}"}
    _tachyon_send(hsocket, data)

    player_client = Client.get_client_by_id(player.id)
    assert player_client.lobby_id == nil
  end

  test "error with no name", %{host: host, player: player, hsocket: hsocket, lobby_id: lobby_id} do
    player_client = Client.get_client_by_id(player.id)
    assert player_client.player == true

    data = %{cmd: "c.lobby.message", userid: host.id, message: "!force kick noname"}
    _tachyon_send(hsocket, data)

    # They should not be kicked, we expect no other errors at this stage
    player_client = Client.get_client_by_id(player.id)
    assert player_client.lobby_id == lobby_id
  end

  test "ban by name", %{host: host, player: player, hsocket: hsocket} do
    player_client = Client.get_client_by_id(player.id)
    assert player_client.player == true

    data = %{cmd: "c.lobby.message", userid: host.id, message: "!force ban #{player.name}"}
    _tachyon_send(hsocket, data)

    player_client = Client.get_client_by_id(player.id)
    assert player_client.lobby_id == nil
  end

  test "ban by partial name", %{host: host, player: player, hsocket: hsocket} do
    player_client = Client.get_client_by_id(player.id)
    assert player_client.player == true

    data = %{cmd: "c.lobby.message", userid: host.id, message: "!force ban #{player.name |> String.slice(0, 17)}"}
    _tachyon_send(hsocket, data)

    player_client = Client.get_client_by_id(player.id)
    assert player_client.lobby_id == nil
  end

  test "blacklist", %{lobby_id: lobby_id, host: host, player: player, hsocket: hsocket} do
    blacklist = Coordinator.call_consul(lobby_id, {:get, :blacklist})
    assert blacklist == %{}

    data = %{cmd: "c.lobby.message", userid: host.id, message: "!force blacklist ##{player.id} banned"}
    _tachyon_send(hsocket, data)
    blacklist = Coordinator.call_consul(lobby_id, {:get, :blacklist})
    assert blacklist == %{
      player.id => :banned
    }

    data = %{cmd: "c.lobby.message", userid: host.id, message: "!force blacklist ##{player.id} spectator"}
    _tachyon_send(hsocket, data)
    blacklist = Coordinator.call_consul(lobby_id, {:get, :blacklist})
    assert blacklist == %{
      player.id => :spectator
    }

    data = %{cmd: "c.lobby.message", userid: host.id, message: "!force blacklist ##{player.id} player"}
    _tachyon_send(hsocket, data)
    blacklist = Coordinator.call_consul(lobby_id, {:get, :blacklist})
    assert blacklist == %{}
  end

  test "whitelist", %{lobby_id: lobby_id, host: host, player: player, hsocket: hsocket} do
    whitelist = Coordinator.call_consul(lobby_id, {:get, :whitelist})
    assert whitelist == %{
      :default => :player
    }

    data = %{cmd: "c.lobby.message", userid: host.id, message: "!force whitelist ##{player.id} spectator"}
    _tachyon_send(hsocket, data)
    whitelist = Coordinator.call_consul(lobby_id, {:get, :whitelist})
    assert whitelist == %{
      player.id => :spectator,
      :default => :player
    }

    data = %{cmd: "c.lobby.message", userid: host.id, message: "!force whitelist ##{player.id} player"}
    _tachyon_send(hsocket, data)
    whitelist = Coordinator.call_consul(lobby_id, {:get, :whitelist})
    assert whitelist == %{
      player.id => :player,
      :default => :player
    }

    data = %{cmd: "c.lobby.message", userid: host.id, message: "!force whitelist ##{player.id} banned"}
    _tachyon_send(hsocket, data)
    whitelist = Coordinator.call_consul(lobby_id, {:get, :whitelist})
    assert whitelist == %{
      :default => :player
    }

    data = %{cmd: "c.lobby.message", userid: host.id, message: "!force whitelist default banned"}
    _tachyon_send(hsocket, data)
    whitelist = Coordinator.call_consul(lobby_id, {:get, :whitelist})
    assert whitelist == %{
      :default => :banned
    }
  end

  test "whitelist player-as-is", %{lobby_id: lobby_id, player: player1, host: host, hsocket: hsocket} do
    %{user: player2} = tachyon_auth_setup()
    %{user: _player3} = tachyon_auth_setup()

    # Add player2 to the battle but as a spectator
    # player3 is not touched, they should not appear on this list
    Lobby.add_user_to_battle(player2.id, lobby_id, "script_password")
    player_client = Client.get_client_by_id(player2.id)
    Client.update(%{player_client |
      player: false
    }, :client_updated_battlestatus)

    data = %{cmd: "c.lobby.message", userid: host.id, message: "!force whitelist player-as-is"}
    _tachyon_send(hsocket, data)

    whitelist = Coordinator.call_consul(lobby_id, {:get, :whitelist})
    assert whitelist == %{
      player1.id => :player,
      player2.id => :spectator,
      :default => :spectator
    }
  end

  test "makeready", %{lobby_id: lobby_id, player: player1, host: host, hsocket: hsocket} do
    %{user: player2} = tachyon_auth_setup()

    # Add player2 to the battle but as a spectator
    Lobby.add_user_to_battle(player2.id, lobby_id, "script_password")
    player_client = Client.get_client_by_id(player2.id)
    Client.update(%{player_client |
      player: false,
      ready: false
    }, :client_updated_battlestatus)

    readies = Lobby.get_battle!(lobby_id)
    |> Map.get(:players)
    |> Enum.map(fn userid -> Client.get_client_by_id(userid) |> Map.get(:ready) end)

    assert readies == [false, false]

    data = %{cmd: "c.lobby.message", userid: host.id, message: "!force makeready"}
    _tachyon_send(hsocket, data)

    # Now we get the ready statuses
    readies = Lobby.get_battle!(lobby_id)
    |> Map.get(:players)
    |> Enum.map(fn userid -> Client.get_client_by_id(userid) |> Map.get(:ready) end)

    assert readies == [true, true]

    # Unready both again
    player_client = Client.get_client_by_id(player1.id)
    Client.update(%{player_client | ready: false}, :client_updated_battlestatus)

    player_client = Client.get_client_by_id(player2.id)
    Client.update(%{player_client | ready: false}, :client_updated_battlestatus)

    readies = Lobby.get_battle!(lobby_id)
    |> Map.get(:players)
    |> Enum.map(fn userid -> Client.get_client_by_id(userid) |> Map.get(:ready) end)

    assert readies == [false, false]

    # Now make one of them ready
    data = %{cmd: "c.lobby.message", userid: host.id, message: "!force makeready ##{player1.id}"}
    _tachyon_send(hsocket, data)

    readies = Lobby.get_battle!(lobby_id)
    |> Map.get(:players)
    |> Enum.map(fn userid -> Client.get_client_by_id(userid) |> Map.get(:ready) end)

    assert readies == [false, true]
  end

  test "status", %{lobby_id: lobby_id, host: host, hsocket: hsocket} do
    data = %{cmd: "c.lobby.message", userid: host.id, message: "!force status"}
    _tachyon_send(hsocket, data)

    reply = _tachyon_recv(hsocket)
    assert reply["cmd"] == "s.communication.direct_message"
    assert reply["sender"] == Coordinator.get_coordinator_userid()
    assert reply["message"] == ["Status for battle ##{lobby_id}", "Gatekeeper: blacklist"]
  end

  test "help", %{host: host, hsocket: hsocket} do
    data = %{cmd: "c.lobby.message", userid: host.id, message: "!help"}
    _tachyon_send(hsocket, data)

    reply = _tachyon_recv(hsocket)
    assert reply["cmd"] == "s.communication.direct_message"
    assert reply["sender"] == Coordinator.get_coordinator_userid()
    assert reply["message"] == ["Command list can currently be found at https://github.com/beyond-all-reason/teiserver/blob/master/lib/teiserver/coordinator/coordinator_lib.ex"]
  end

  test "pull user", %{lobby_id: lobby_id, host: host, hsocket: hsocket} do
    %{user: player2, socket: psocket} = tachyon_auth_setup()

    data = %{cmd: "c.lobby.message", userid: host.id, message: "!force pull ##{player2.id}"}
    _tachyon_send(hsocket, data)

    reply = _tachyon_recv(psocket)
    assert reply["cmd"] == "s.lobby.join_response"
    assert reply["lobby"]["id"] == lobby_id
  end

  test "modban", %{lobby_id: lobby_id, host: host, hsocket: hsocket, player: player, listener: listener} do
    assert User.is_muted?(player.id) == false
    assert User.is_banned?(player.id) == false

    data = %{cmd: "c.lobby.message", userid: host.id, message: "!modban #{player.name} 60 Spamming channel"}
    _tachyon_send(hsocket, data)

    messages = PubsubListener.get(listener)
    assert messages == [{:battle_updated, lobby_id, {Coordinator.get_coordinator_userid(), "#{player.name} banned for 60 minutes by #{host.name}, reason: Spamming channel", lobby_id}, :say}]

    assert User.is_muted?(player.id) == false
    assert User.is_banned?(player.id) == true
  end

  test "modmute", %{lobby_id: lobby_id, host: host, hsocket: hsocket, player: player, listener: listener} do
    assert User.is_muted?(player.id) == false
    assert User.is_banned?(player.id) == false

    data = %{cmd: "c.lobby.message", userid: host.id, message: "!modmute #{player.name} 60 Spamming channel"}
    _tachyon_send(hsocket, data)

    messages = PubsubListener.get(listener)
    assert messages == [{:battle_updated, lobby_id, {Coordinator.get_coordinator_userid(), "#{player.name} muted for 60 minutes by #{host.name}, reason: Spamming channel", lobby_id}, :say}]

    assert User.is_muted?(player.id) == true
    assert User.is_banned?(player.id) == false
  end

  test "test passthrough", %{lobby_id: lobby_id, host: host, hsocket: hsocket, listener: listener} do
    data = %{cmd: "c.lobby.message", userid: host.id, message: "!force non-existing command"}
    _tachyon_send(hsocket, data)

    messages = PubsubListener.get(listener)
    assert messages == [{:battle_updated, lobby_id, {host.id, "!force non-existing command", lobby_id}, :say}]

    reply = _tachyon_recv(hsocket)
    assert reply == :timeout
  end
end
