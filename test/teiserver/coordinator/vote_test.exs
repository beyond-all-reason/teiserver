defmodule Teiserver.Coordinator.VoteTest do
use Central.ServerCase, async: false
  alias Teiserver.Battle.Lobby
  alias Teiserver.Common.PubsubListener
  alias Teiserver.{Client, Coordinator}
  alias Teiserver.Account.UserCache

  import Teiserver.TeiserverTestLib,
    only: [tachyon_auth_setup: 0, _tachyon_send: 2, _tachyon_recv: 1, _tachyon_recv_until: 1]

  setup do
    Teiserver.Coordinator.start_coordinator()
    %{socket: hsocket, user: host} = tachyon_auth_setup()
    %{socket: psocket, user: player} = tachyon_auth_setup()

    # Host is a moderator
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
    Lobby.force_add_user_to_battle(player.id, lobby_id)
    _ = _tachyon_recv_until(psocket)

    player_client = Client.get_client_by_id(player.id)
    Client.update(%{player_client |
      player: true
    }, :client_updated_battlestatus)

    {:ok, hsocket: hsocket, psocket: psocket, host: host, player: player, lobby_id: lobby_id, listener: listener}
  end

  test "moderator only command", %{lobby_id: lobby_id, host: _host, hsocket: hsocket} do
    %{user: _player2, socket: psocket} = tachyon_auth_setup()

    battle = Lobby.get_battle!(lobby_id)
    assert battle.coordinator_mode == true

    data = %{cmd: "c.lobby.message", message: "!specunready"}
    _tachyon_send(hsocket, data)

    reply = _tachyon_recv(psocket)
    assert reply == :timeout
  end

  test "small lobby", %{lobby_id: lobby_id, host: _host, hsocket: _hsocket, player: player, psocket: psocket} do
    battle = Lobby.get_battle!(lobby_id)
    assert battle.coordinator_mode == true

    # Check no vote at this stage
    current_vote = Coordinator.call_consul(lobby_id, {:get, :current_vote})
    assert current_vote == nil

    # Create it
    data = %{cmd: "c.lobby.message", message: "!changemap map_name"}
    _tachyon_send(psocket, data)

    # Listen
    reply = _tachyon_recv(psocket)
    assert reply == %{
      "cmd" => "s.lobby.message",
      "message" => "! changemap map_name",
      "sender" => player.id
    }

    # Check consul state
    current_vote = Coordinator.call_consul(lobby_id, {:get, :current_vote})
    assert current_vote == nil
  end

  test "vote lifecycle", %{lobby_id: lobby_id, host: _host, hsocket: _hsocket, player: player1, psocket: psocket1} do
    # We need more players in the game to test this properly
    %{socket: psocket2, user: player2} = tachyon_auth_setup()
    %{socket: psocket3, user: player3} = tachyon_auth_setup()
    %{socket: psocket4, user: player4} = tachyon_auth_setup()
    %{socket: ssocket1, user: spec1} = tachyon_auth_setup()

    Lobby.force_add_user_to_battle(player2.id, lobby_id)
    Lobby.force_add_user_to_battle(player3.id, lobby_id)
    Lobby.force_add_user_to_battle(player4.id, lobby_id)
    Lobby.force_add_user_to_battle(spec1.id, lobby_id)

    _tachyon_recv_until(psocket2)
    _tachyon_recv_until(psocket3)
    _tachyon_recv_until(psocket4)

    Client.update(%{Client.get_client_by_id(player2.id) |
      player: true
    }, :client_updated_battlestatus)
    Client.update(%{Client.get_client_by_id(player3.id) |
      player: true
    }, :client_updated_battlestatus)
    Client.update(%{Client.get_client_by_id(player4.id) |
      player: true
    }, :client_updated_battlestatus)


    battle = Lobby.get_battle!(lobby_id)
    assert battle.coordinator_mode == true

    # Check no vote at this stage
    current_vote = Coordinator.call_consul(lobby_id, {:get, :current_vote})
    assert current_vote == nil

    # Create it
    data = %{cmd: "c.lobby.message", message: "!changemap map_name"}
    _tachyon_send(psocket1, data)

    # Listen
    reply = _tachyon_recv(psocket1)
    assert reply == %{
      "cmd" => "s.lobby.announce",
      "message" => "#{player1.name} called a vote for command \"changemap map_name\" [Vote !y, !n, !b]",
      "sender" => Coordinator.get_coordinator_userid()
    }

    # Check consul state
    current_vote = Coordinator.call_consul(lobby_id, {:get, :current_vote})
    assert current_vote.abstains == []
    assert current_vote.yays == [player1.id]
    assert current_vote.nays == []
    assert current_vote.creator_id == player1.id
    assert current_vote.expires != nil
    assert current_vote.cmd == %{command: "changemap", error: nil, force: false, raw: "!changemap map_name", remaining: "map_name", senderid: player1.id, silent: false, vote: true}
    assert Enum.sort(current_vote.eligible) == Enum.sort([player4.id, player3.id, player2.id, player1.id])

    # Now lets cancel the vote as a different player, we expect to see nothing
    data = %{cmd: "c.lobby.message", message: "!ev"}
    _tachyon_send(psocket2, data)

    reply = _tachyon_recv(psocket1)
    assert reply == :timeout

    current_vote = Coordinator.call_consul(lobby_id, {:get, :current_vote})
    assert current_vote != nil

    # If player1 calls !ev then it should be ended
    data = %{cmd: "c.lobby.message", message: "!ev"}
    _tachyon_send(psocket1, data)

    reply = _tachyon_recv(psocket1)
    assert reply == %{
      "cmd" => "s.lobby.announce",
      "message" => "Vote cancelled by #{player1.name}",
      "sender" => Coordinator.get_coordinator_userid()
    }

    current_vote = Coordinator.call_consul(lobby_id, {:get, :current_vote})
    assert current_vote == nil

    # What happens if we try to vote on a vote that doesn't exist?
    _tachyon_send(psocket1, %{cmd: "c.lobby.message", message: "!y"})

    # Now do some voting

    # _ = _tachyon_recv_until(psocket)
  end
end
