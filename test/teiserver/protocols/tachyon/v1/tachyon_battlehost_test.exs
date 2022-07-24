defmodule Teiserver.Protocols.V1.TachyonBattleHostTest do
  use Central.ServerCase
  alias Teiserver.Battle
  alias Teiserver.Battle.Lobby
  require Logger

  import Teiserver.TeiserverTestLib,
    only: [tachyon_auth_setup: 0, _tachyon_send: 2, _tachyon_recv: 1, _tachyon_recv_until: 1]

  setup do
    %{socket: socket, user: user, pid: pid} = tachyon_auth_setup()
    {:ok, socket: socket, user: user, pid: pid}
  end

  test "lobby host", %{socket: socket, pid: pid} do
    # Open the lobby
    lobby_data = %{
      cmd: "c.lobby.create",
      name: "EU 01 - 123",
      nattype: "none",
      password: "password2",
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
    _tachyon_send(socket, data)
    [reply] = _tachyon_recv(socket)

    assert Map.has_key?(reply, "lobby")
    assert match?(%{"cmd" => "s.lobby.create", "result" => "success"}, reply)
    lobby = reply["lobby"]

    assert lobby["name"] == "EU 01 - 123"
    assert lobby["map_name"] == "koom valley"
    lobby_id = lobby["id"]

    assert GenServer.call(pid, {:get, :lobby_id}) == lobby_id
    assert GenServer.call(pid, {:get, :lobby_host}) == true
    assert Lobby.get_lobby(lobby_id) != nil

    # Now create a user to join the lobby
    %{socket: socket2, user: user2, pid: pid2} = tachyon_auth_setup()
    %{socket: socket3, user: user3} = tachyon_auth_setup()
    %{socket: socket4, user: _user4} = tachyon_auth_setup()

    # Bad password
    _tachyon_send(socket2, %{cmd: "c.lobby.join", lobby_id: lobby_id})
    reply = _tachyon_recv(socket2)

    assert reply == [%{
      "cmd" => "s.lobby.join",
      "result" => "failure",
      "reason" => "Invalid password"
    }]

    # Good password
    # We send from both users to test for a bug found when making the agent system
    # where two messages queued up might not be decoded correctly
    data = %{cmd: "c.lobby.join", lobby_id: lobby_id, password: "password2"}
    _tachyon_send(socket2, data)
    _tachyon_send(socket3, data)
    reply = _tachyon_recv(socket2)

    assert reply == [%{
      "cmd" => "s.lobby.join",
      "result" => "waiting_for_host"
    }]

    # Host is expecting to see a request
    [reply] = _tachyon_recv(socket)
    assert reply["cmd"] == "s.lobby_host.user_requests_to_join"
    assert reply["userid"] == user2.id

    # Here should be the next request
    [reply] = _tachyon_recv(socket)
    assert reply["cmd"] == "s.lobby_host.user_requests_to_join"
    assert reply["userid"] == user3.id

    # Host can reject
    data = %{cmd: "c.lobby_host.respond_to_join_request", userid: user2.id, response: "reject", reason: "reason given"}
    _tachyon_send(socket, data)
    reply = _tachyon_recv(socket2)

    # Reject user3 at the same time
    data = %{cmd: "c.lobby_host.respond_to_join_request", userid: user3.id, response: "reject", reason: "reason given"}
    _tachyon_send(socket, data)

    assert reply == [%{
      "cmd" => "s.lobby.join_response",
      "result" => "reject",
      "reason" => "reason given",
      "lobby_id" => lobby_id
    }]

    # Now request again but this time accept
    _tachyon_send(socket2, %{cmd: "c.lobby.join", lobby_id: lobby_id, password: "password2"})
    _tachyon_recv(socket2)
    _tachyon_recv(socket)

    assert GenServer.call(pid2, {:get, :lobby_id}) == nil

    data = %{cmd: "c.lobby_host.respond_to_join_request", userid: user2.id, response: "approve"}
    _tachyon_send(socket, data)
    [reply] = _tachyon_recv(socket2)

    assert reply["cmd"] == "s.lobby.join_response"
    assert reply["result"] == "approve"
    assert reply["lobby"]["id"] == lobby_id

    assert GenServer.call(pid2, {:get, :lobby_id}) == lobby_id

    # Add user, we can ignore this
    _tachyon_recv(socket)

    # Ensure the lobby state is accurate
    _tachyon_send(socket2, %{cmd: "c.lobby.query", query: %{id_list: [lobby_id]}})
    [reply] = _tachyon_recv(socket2)

    assert reply["cmd"] == "s.lobby.query"
    assert Enum.count(reply["lobbies"]) == 1
    lobby = hd(reply["lobbies"])["lobby"]
    assert lobby["id"] == lobby_id
    assert lobby["players"] == [user2.id]

    # Now do the same but with some fields selected
    _tachyon_send(socket2, %{
      cmd: "c.lobby.query",
      query: %{id_list: [lobby_id]},
      fields: ["lobby", "modoptions", "bots", "players", "members"]
    })
    [reply] = _tachyon_recv(socket2)

    assert reply["cmd"] == "s.lobby.query"
    assert Enum.count(reply["lobbies"]) == 1
    lobby = hd(reply["lobbies"])
    assert lobby["lobby"]["id"] == lobby_id
    assert lobby["lobby"]["players"] == [user2.id]
    assert lobby["members"] == [user2.id]
    assert lobby["players"] == []

    # Use the get command
    _tachyon_send(socket2, %{cmd: "c.lobby.get", lobby_id: lobby_id, keys: ~w(bots modoptions players members)})
    [reply] = _tachyon_recv(socket2)
    assert reply == %{
      "cmd" => "s.lobby.get",
      "bots" => %{},
      "lobby_id" => lobby_id,
      "modoptions" => %{
        "server/match/uuid" => Battle.get_lobby_match_uuid(lobby_id)
      },
      "members" => [
        %{"away" => false, "in_game" => false, "lobby_id" => lobby_id, "player" => false, "player_number" => 0, "ready" => false, "sync" => %{"engine" => 0, "game" => 0, "map" => 0}, "team_colour" => 0, "team_number" => 0, "userid" => user2.id}
      ],
      "players" => []
    }

    # Accept player3
    _tachyon_recv_until(socket3)
    _tachyon_send(socket3, %{cmd: "c.lobby.join", lobby_id: lobby_id, password: "password2"})
    _tachyon_recv(socket3)
    _tachyon_recv(socket)

    data = %{cmd: "c.lobby_host.respond_to_join_request", userid: user3.id, response: "approve"}
    _tachyon_send(socket, data)
    [reply] = _tachyon_recv(socket3)

    assert reply["cmd"] == "s.lobby.join_response"
    assert reply["result"] == "approve"
    assert reply["lobby"]["id"] == lobby_id

    # Ensure the lobby state is accurate
    data = %{cmd: "c.lobby.query", query: %{id_list: [lobby_id]}}
    _tachyon_send(socket3, data)
    [reply] = _tachyon_recv(socket3)

    assert reply["cmd"] == "s.lobby.query"
    assert Enum.count(reply["lobbies"]) == 1
    lobby = hd(reply["lobbies"])["lobby"]
    assert lobby["id"] == lobby_id
    assert lobby["players"] == [user3.id, user2.id]

    # We now have two members, we need to update their statuses
    # reset all socket messages
    _tachyon_recv_until(socket)
    _tachyon_recv_until(socket2)
    _tachyon_recv_until(socket3)

    _tachyon_send(socket2, %{cmd: "c.lobby.update_status", client: %{player: true, team_number: 3, ready: true}})
    [replyh] = _tachyon_recv(socket)
    [reply2] = _tachyon_recv(socket2)
    [reply3] = _tachyon_recv(socket3)

    assert replyh == reply2
    assert reply2 == reply3
    assert reply2["cmd"] == "s.lobby.updated_client_battlestatus"
    assert reply2["lobby_id"] == lobby_id
    assert reply2["client"]["player"] == true
    assert reply2["client"]["team_number"] == 3

    # User4, they shouldn't have seen any of this
    reply = _tachyon_recv_until(socket4)
    assert reply == []

    # User4 can attempt to watch the lobby though!
    _tachyon_recv_until(socket4)
    _tachyon_send(socket4, %{cmd: "c.lobby.watch", lobby_id: lobby_id})
    [reply] = _tachyon_recv(socket4)
    assert reply == %{
      "cmd" => "s.lobby.watch",
      "result" => "success",
      "lobby_id" => lobby_id
    }

    # And if we send the wrong lobby id?
    _tachyon_recv_until(socket4)
    _tachyon_send(socket4, %{cmd: "c.lobby.watch", lobby_id: -1000})
    [reply] = _tachyon_recv(socket4)
    assert reply == %{
      "cmd" => "s.lobby.watch",
      "result" => "failure",
      "reason" => "No lobby",
      "lobby_id" => -1000
    }

    # Flush socket
    _tachyon_recv_until(socket)

    # Add a bot
    Logger.warn("#{__ENV__.file}.#{__ENV__.line} should add, update and remove the bot via Tachyon commands")
    Battle.add_bot_to_lobby(lobby_id, %{
      ai_dll: "BARb",
      handicap: 0,
      name: "BARbarianAI(10)",
      owner_id: 8603,
      owner_name: "Mustard",
      player: true,
      player_number: 8,
      ready: true,
      side: 1,
      sync: %{"engine" => 1, "game" => 1, "map" => 1},
      team_colour: "42537",
      team_number: 2
    })

    [reply] = _tachyon_recv_until(socket)
    assert reply == %{
      "bot" => %{
      "ai_dll" => "BARb",
      "handicap" => 0,
      "name" => "BARbarianAI(10)",
      "owner_id" => 8603,
      "owner_name" => "Mustard",
      "player" => true,
      "player_number" => 8,
      "ready" => true,
      "side" => 1,
      "sync" => %{"engine" => 1, "game" => 1, "map" => 1},
      "team_colour" => "42537",
      "team_number" => 2
      },
      "cmd" => "s.lobby.add_bot"
    }

    # Update the bot
    Battle.update_bot(lobby_id, "BARbarianAI(10)", %{
      ai_dll: "BARb",
      handicap: 0,
      name: "BARbarianAI(10)",
      owner_id: 8603,
      owner_name: "Mustard",
      player: true,
      player_number: 8,
      ready: true,
      side: 1,
      sync: %{"engine" => 1, "game" => 1, "map" => 1},
      team_colour: "123445",
      team_number: 2
    })

    [reply] = _tachyon_recv_until(socket)
    assert reply == %{
      "bot" => %{
        "ai_dll" => "BARb",
        "handicap" => 0,
        "name" => "BARbarianAI(10)",
        "owner_id" => 8603,
        "owner_name" => "Mustard",
        "player" => true,
        "player_number" => 8,
        "ready" => true,
        "side" => 1,
        "sync" => %{"engine" => 1, "game" => 1, "map" => 1},
        "team_colour" => "123445",
        "team_number" => 2
      },
      "cmd" => "s.lobby.update_bot"
    }

    # Remove bot
    Battle.remove_bot(lobby_id, "BARbarianAI(10)")
    [reply] = _tachyon_recv_until(socket)
    assert reply == %{
      "bot_name" => "BARbarianAI(10)",
      "cmd" => "s.lobby.remove_bot"
    }

    # Set mod options
    Logger.warn("#{__ENV__.file}.#{__ENV__.line} should add, update and remove modoptions via the Tachyon command")

    Battle.set_modoption(lobby_id, "singe_key", "single_value")
    [reply] = _tachyon_recv_until(socket)
    assert reply == %{
      "cmd" => "s.lobby.set_modoptions",
      "new_options" => %{"singe_key" => "single_value"}
    }

    Battle.set_modoptions(lobby_id, %{
      "multi_key1" => "multi_value1",
      "multi_key2" => "multi_value2"
    })
    [reply] = _tachyon_recv_until(socket)
    assert reply == %{
      "cmd" => "s.lobby.set_modoptions",
      "new_options" => %{
        "multi_key1" => "multi_value1",
        "multi_key2" => "multi_value2"
      }
    }

    Battle.remove_modoptions(lobby_id, ["singe_key", "non-existing-key"])
    [reply] = _tachyon_recv_until(socket)
    assert reply == %{
      "cmd" => "s.lobby.remove_modoptions",
      "keys" => ["singe_key"]
    }

    # Start areas
    Logger.warn("#{__ENV__.file}.#{__ENV__.line} should add, update and remove start areas via the Tachyon command")
    Battle.add_start_area(lobby_id, 1, ["rect", 1, 2, 3, 4])

    [reply] = _tachyon_recv_until(socket)
    assert reply == %{
      "cmd" => "s.lobby.add_start_area",
      "lobby_id" => lobby_id,
      "area_id" => 1,
      "structure" => ["rect", 1, 2, 3, 4]
    }


    Battle.add_start_area(lobby_id, 1, ["rect", 10, 12, 24, 35])

    [reply] = _tachyon_recv_until(socket)
    assert reply == %{
      "cmd" => "s.lobby.add_start_area",
      "lobby_id" => lobby_id,
      "area_id" => 1,
      "structure" => ["rect", 10, 12, 24, 35]
    }


    Battle.remove_start_area(lobby_id, 1)

    [reply] = _tachyon_recv_until(socket)
    assert reply == %{
      "cmd" => "s.lobby.remove_start_area",
      "lobby_id" => lobby_id,
      "area_id" => 1
    }

    # Now leave the lobby, closing it in the process
    data = %{cmd: "c.lobby.leave"}
    _tachyon_send(socket, data)
    [reply] = _tachyon_recv(socket)
    assert match?(%{"cmd" => "s.lobby.leave"}, reply)

    assert GenServer.call(pid, {:get, :lobby_id}) == nil
    assert GenServer.call(pid, {:get, :lobby_host}) == false
    assert Lobby.get_lobby(lobby_id) == nil
  end
end
