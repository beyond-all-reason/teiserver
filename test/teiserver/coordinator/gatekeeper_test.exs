defmodule Teiserver.Coordinator.GatekeeperTest do
  use Central.ServerCase, async: false
  alias Teiserver.Battle.Lobby
  alias Teiserver.Common.PubsubListener
  alias Teiserver.{Client, User, Coordinator}

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
    Lobby.force_add_user_to_battle(player.id, battle_id)
    :timer.sleep(100)
    player_client = Client.get_client_by_id(player.id)
    Client.update(%{player_client |
      player: true
    }, :client_updated_battlestatus)

    {:ok, hsocket: hsocket, psocket: psocket, host: host, player: player, battle_id: battle_id, listener: listener}
  end

  test "blacklist", %{host: host, player: player, hsocket: hsocket, psocket: psocket, battle_id: battle_id} do
    player_client = Client.get_client_by_id(player.id)
    assert player_client.player == true
    assert player_client.battle_id == battle_id

    # Blacklist them to spectator
    _tachyon_send(hsocket, %{cmd: "c.battle.message", userid: host.id, message: "!blacklist ##{player.id} spectator"})

    # Check it's worked
    player_client = Client.get_client_by_id(player.id)
    assert player_client.player == false
    assert player_client.battle_id == battle_id

    # Try to change it
    _tachyon_send(psocket, %{cmd: "c.battle.update_status", player: true})

    # Still working
    player_client = Client.get_client_by_id(player.id)
    assert player_client.player == false
    assert player_client.battle_id == battle_id

    # Un-blacklist them
    _tachyon_send(hsocket, %{cmd: "c.battle.message", userid: host.id, message: "!blacklist ##{player.id} player"})

    # Try to change it
    data = %{cmd: "c.battle.update_status", player: true}
    _tachyon_send(psocket, data)

    # Back to being allowed
    player_client = Client.get_client_by_id(player.id)
    assert player_client.player == true
    assert player_client.battle_id == battle_id

    # Now we bring in player 2
    %{user: player2} = tachyon_auth_setup()
    _tachyon_send(hsocket, %{cmd: "c.battle.message", userid: host.id, message: "!blacklist ##{player2.id} banned"})

    assert Lobby.can_join?(player2.id, battle_id) == {:failure, "Denied by Coordinator"}

    # Un-ban
    _tachyon_send(hsocket, %{cmd: "c.battle.message", userid: host.id, message: "!blacklist ##{player2.id} spectator"})
    assert Lobby.can_join?(player2.id, battle_id) == {:waiting_on_host, nil}
  end

  test "whitelist", %{host: host, player: player, hsocket: hsocket, psocket: psocket, battle_id: battle_id} do
    player_client = Client.get_client_by_id(player.id)
    assert player_client.player == true
    assert player_client.battle_id == battle_id

    # If we set whitelist default to banned it should have everybody already in the game still allowed
    _tachyon_send(hsocket, %{cmd: "c.battle.message", userid: host.id, message: "!whitelist default banned"})
    whitelist = Coordinator.call_consul(battle_id, {:get, :whitelist})
    assert whitelist == %{:default => :banned, player.id => :player}

    # Whitelist them to spectator but defaults to player
    _tachyon_send(hsocket, %{cmd: "c.battle.message", userid: host.id, message: "!gatekeeper whitelist"})
    _tachyon_send(hsocket, %{cmd: "c.battle.message", userid: host.id, message: "!whitelist ##{player.id} spectator"})
    _tachyon_send(hsocket, %{cmd: "c.battle.message", userid: host.id, message: "!whitelist default player"})

    # Check state
    gatekeeper = Coordinator.call_consul(battle_id, {:get, :gatekeeper})
    assert gatekeeper == :whitelist
    whitelist = Coordinator.call_consul(battle_id, {:get, :whitelist})
    assert whitelist == %{:default => :player, player.id => :spectator}

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

    # Un-whitelist them
    data = %{cmd: "c.battle.message", userid: host.id, message: "!whitelist ##{player.id} player"}
    _tachyon_send(hsocket, data)

    # Try to change it
    data = %{cmd: "c.battle.update_status", player: true}
    _tachyon_send(psocket, data)

    # Back to being allowed
    player_client = Client.get_client_by_id(player.id)
    assert player_client.player == true
    assert player_client.battle_id == battle_id

    # Now we bring in player 2
    %{user: player2} = tachyon_auth_setup()
    _tachyon_send(hsocket, %{cmd: "c.battle.message", userid: host.id, message: "!whitelist default banned"})
    assert Lobby.can_join?(player2.id, battle_id) == {:failure, "Denied by Coordinator"}

    # Un-ban
    _tachyon_send(hsocket, %{cmd: "c.battle.message", userid: host.id, message: "!whitelist ##{player2.id} spectator"})
    assert Lobby.can_join?(player2.id, battle_id) == {:waiting_on_host, nil}
  end

  test "friends", %{host: host, player: player, hsocket: hsocket, psocket: psocket, battle_id: battle_id} do
    player_client = Client.get_client_by_id(player.id)
    assert player_client.player == true
    assert player_client.battle_id == battle_id

    # Whitelist them to spectator but defaults to player
    _tachyon_send(hsocket, %{cmd: "c.battle.message", userid: host.id, message: "!gatekeeper friends"})
    _tachyon_send(hsocket, %{cmd: "c.battle.message", userid: host.id, message: "!force-spectator ##{player.id}"})

    # Check state
    gatekeeper = Coordinator.call_consul(battle_id, {:get, :gatekeeper})
    assert gatekeeper == :friends

    # Check it's worked
    player_client = Client.get_client_by_id(player.id)
    assert player_client.player == false
    assert player_client.battle_id == battle_id

    # Try to change it
    data = %{cmd: "c.battle.update_status", player: true}
    _tachyon_send(psocket, data)

    # No players, we should be able to become a player even though having no "friends" in the game
    player_client = Client.get_client_by_id(player.id)
    assert player_client.player == true
    assert player_client.battle_id == battle_id

    # Now for player 2
    _tachyon_send(hsocket, %{cmd: "c.battle.message", userid: host.id, message: "!gatekeeper friends"})

    # Now we bring in player 2, they should be allowed in
    %{user: player2, socket: psocket2} = tachyon_auth_setup()
    assert Lobby.can_join?(player2.id, battle_id) == {:waiting_on_host, nil}

    # Okay, add them
    Lobby.force_add_user_to_battle(player2.id, battle_id)
    data = %{cmd: "c.battle.update_status", player: true}
    _tachyon_send(psocket2, data)

    player_client2 = Client.get_client_by_id(player2.id)
    assert player_client2.player == false
    assert player_client2.battle_id == battle_id
  end

  test "friendsjoin", %{host: host, player: player, psocket: psocket, hsocket: hsocket, battle_id: battle_id} do
    player_client = Client.get_client_by_id(player.id)
    assert player_client.player == true
    assert player_client.battle_id == battle_id

    # Whitelist them to spectator but defaults to player
    _tachyon_send(hsocket, %{cmd: "c.battle.message", userid: host.id, message: "!gatekeeper friendsjoin"})
    _tachyon_send(hsocket, %{cmd: "c.battle.message", userid: host.id, message: "!force-spectator ##{player.id}"})

    # Check state
    gatekeeper = Coordinator.call_consul(battle_id, {:get, :gatekeeper})
    assert gatekeeper == :friendsjoin

    # They should still be here
    player_client = Client.get_client_by_id(player.id)
    assert player_client.player == false
    assert player_client.battle_id == battle_id

    # Try to change it
    data = %{cmd: "c.battle.update_status", player: true}
    _tachyon_send(psocket, data)

    # Change should be fine
    player_client = Client.get_client_by_id(player.id)
    assert player_client.player == true
    assert player_client.battle_id == battle_id

    # Now we bring in player 2, they should not be allowed in
    %{user: player2} = tachyon_auth_setup()
    assert Lobby.can_join?(player2.id, battle_id) == {:waiting_on_host, nil}
  end

  # test "clan", %{host: host, player: player, hsocket: hsocket, psocket: psocket, battle_id: battle_id} do

  # end
end
