defmodule Teiserver.Protocols.V1.TachyonBattleHostTest do
  use Central.ServerCase
  alias Teiserver.{Battle, Account}
  alias Teiserver.Battle.Lobby
  require Logger

  import Teiserver.TeiserverTestLib,
    only: [tachyon_auth_setup: 0, _tachyon_send: 2, _tachyon_recv: 1, _tachyon_recv_until: 1]

  setup do
    %{socket: socket, user: user, pid: pid} = tachyon_auth_setup()
    {:ok, socket: socket, user: user, pid: pid}
  end

  test "lobby host", %{socket: socket, pid: pid, user: host} do
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

    assert reply == [
             %{
               "cmd" => "s.lobby.join",
               "result" => "failure",
               "reason" => "Invalid password"
             }
           ]

    # We have a whole bunch of these because at one stage there was a bug where user2 was
    # marked as present in the lobby when they should not have been
    assert Account.get_client_by_id(user2.id).lobby_id == nil
    assert GenServer.call(pid2, {:get, :lobby_id}) == nil

    # Good password
    # We send from both users to test for a bug found when making the agent system
    # where two messages queued up might not be decoded correctly
    data = %{cmd: "c.lobby.join", lobby_id: lobby_id, password: "password2"}
    _tachyon_send(socket2, data)
    _tachyon_send(socket3, data)
    reply = _tachyon_recv(socket2)

    assert Account.get_client_by_id(user2.id).lobby_id == nil
    assert GenServer.call(pid2, {:get, :lobby_id}) == nil

    assert reply == [
             %{
               "cmd" => "s.lobby.join",
               "result" => "waiting_for_host"
             }
           ]

    # Host is expecting to see a request
    [reply] = _tachyon_recv(socket)
    assert reply["cmd"] == "s.lobby_host.user_requests_to_join"
    assert reply["userid"] == user2.id

    # Here should be the next request
    [reply] = _tachyon_recv(socket)
    assert reply["cmd"] == "s.lobby_host.user_requests_to_join"
    assert reply["userid"] == user3.id

    # Host can reject
    _tachyon_send(socket, %{
      cmd: "c.lobby_host.respond_to_join_request",
      userid: user2.id,
      response: "reject",
      reason: "reason given"
    })

    [reply] = _tachyon_recv(socket2)

    assert Account.get_client_by_id(user2.id).lobby_id == nil
    assert GenServer.call(pid2, {:get, :lobby_id}) == nil

    assert reply == %{
             "cmd" => "s.lobby.join_response",
             "result" => "reject",
             "lobby_id" => lobby_id,
             "reason" => "reason given"
           }

    # Reject user3 at the same time
    _tachyon_send(socket, %{
      cmd: "c.lobby_host.respond_to_join_request",
      userid: user3.id,
      response: "reject",
      reason: "reason given"
    })

    uuid = Battle.get_lobby_match_uuid(lobby_id)

    # Now request again but this time accept
    _tachyon_send(socket2, %{cmd: "c.lobby.join", lobby_id: lobby_id, password: "password2"})
    _tachyon_recv_until(socket2)
    _tachyon_recv_until(socket)

    assert GenServer.call(pid2, {:get, :lobby_id}) == nil

    data = %{cmd: "c.lobby_host.respond_to_join_request", userid: user2.id, response: "approve"}
    _tachyon_send(socket, data)
    [reply] = _tachyon_recv(socket2)

    script_password = reply["script_password"]

    assert reply == %{
             "cmd" => "s.lobby.joined",
             "script_password" => script_password,
             "bots" => %{},
             "lobby" => %{
               "disabled_units" => [],
               "engine_name" => "spring-105",
               "engine_version" => "105.1.2.3",
               "founder_id" => host.id,
               "game_name" => "BAR",
               "id" => lobby_id,
               "in_progress" => false,
               "ip" => "127.0.0.1",
               "locked" => false,
               "map_hash" => "string_of_characters",
               "map_name" => "koom valley",
               "max_players" => 16,
               "name" => "EU 01 - 123",
               "passworded" => true,
               "players" => [],
               "public" => true,
               "settings" => %{"max_players" => 12},
               "start_areas" => %{},
               "started_at" => nil,
               "type" => "normal",
               "port" => 1234
             },
             "member_list" => [
               %{
                 "away" => false,
                 "clan_tag" => nil,
                 "in_game" => false,
                 "lobby_id" => lobby_id,
                 "muted" => false,
                 "party_id" => nil,
                 "player" => false,
                 "player_number" => 0,
                 "ready" => false,
                 "sync" => %{"engine" => 0, "game" => 0, "map" => 0},
                 "team_colour" => "0",
                 "team_number" => 0,
                 "userid" => user2.id
               }
             ],
             "modoptions" => %{"server/match/uuid" => uuid}
           }

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
      fields: ["lobby", "modoptions", "bots", "players", "member_list"]
    })

    [reply] = _tachyon_recv(socket2)

    assert reply["cmd"] == "s.lobby.query"
    assert Enum.count(reply["lobbies"]) == 1
    lobby = hd(reply["lobbies"])
    assert lobby["lobby"]["id"] == lobby_id
    assert lobby["lobby"]["players"] == [user2.id]
    assert lobby["players"] == []
    assert hd(lobby["member_list"])["userid"] == user2.id
    assert Enum.count(lobby["member_list"]) == 1

    # Use the get command
    _tachyon_send(socket2, %{
      cmd: "c.lobby.get",
      lobby_id: lobby_id,
      keys: ~w(bots modoptions players members)
    })

    [reply] = _tachyon_recv(socket2)

    assert reply == %{
             "cmd" => "s.lobby.get",
             "bots" => %{},
             "lobby_id" => lobby_id,
             "modoptions" => %{
               "server/match/uuid" => Battle.get_lobby_match_uuid(lobby_id)
             },
             "members" => [
               %{
                 "away" => false,
                 "in_game" => false,
                 "lobby_id" => lobby_id,
                 "player" => false,
                 "player_number" => 0,
                 "ready" => false,
                 "sync" => %{"engine" => 0, "game" => 0, "map" => 0},
                 "team_colour" => "0",
                 "team_number" => 0,
                 "userid" => user2.id,
                 "clan_tag" => nil,
                 "muted" => false,
                 "party_id" => nil
               }
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

    assert reply["cmd"] == "s.lobby.joined"
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

    _tachyon_send(socket2, %{
      cmd: "c.lobby.update_status",
      client: %{player: true, team_number: 3, ready: true}
    })

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

    # Flush socket
    _tachyon_recv_until(socket)

    # Add a bot
    data = %{
      cmd: "c.lobby.add_bot",
      name: "BotNumeroUno",
      status: %{
        team_colour: "42537",
        player_number: 8,
        team_number: 2,
        side: 1
      },
      ai_dll: "BARb"
    }

    _tachyon_send(socket2, data)

    [reply] = _tachyon_recv_until(socket)

    assert reply == %{
             "bot" => %{
               "ai_dll" => "BARb",
               "handicap" => 0,
               "name" => "BotNumeroUno",
               "owner_id" => user2.id,
               "owner_name" => user2.name,
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
    data = %{
      cmd: "c.lobby.update_bot",
      name: "BotNumeroUno",
      status: %{
        team_colour: "123445",
        player_number: 6,
        team_number: 1,
        side: 1
      }
    }

    _tachyon_send(socket2, data)

    [reply] = _tachyon_recv_until(socket)

    assert reply == %{
             "bot" => %{
               "ai_dll" => "BARb",
               "handicap" => 0,
               "name" => "BotNumeroUno",
               "owner_id" => user2.id,
               "owner_name" => user2.name,
               "player" => true,
               "player_number" => 6,
               "ready" => true,
               "side" => 1,
               "sync" => %{"engine" => 1, "game" => 1, "map" => 1},
               "team_colour" => "123445",
               "team_number" => 1
             },
             "cmd" => "s.lobby.update_bot"
           }

    # Remove bot
    _tachyon_send(socket2, %{
      cmd: "c.lobby.remove_bot",
      name: "BotNumeroUno"
    })

    [reply] = _tachyon_recv_until(socket)

    assert reply == %{
             "bot_name" => "BotNumeroUno",
             "cmd" => "s.lobby.remove_bot"
           }

    # Set mod options
    Logger.warn(
      "#{__ENV__.file}.#{__ENV__.line} should add, update and remove modoptions via the Tachyon command"
    )

    Battle.set_modoption(lobby_id, "singe_key", "single_value")
    [reply] = _tachyon_recv_until(socket)

    assert reply == %{
             "cmd" => "s.lobby.set_modoptions",
             "lobby_id" => lobby_id,
             "new_options" => %{"singe_key" => "single_value"}
           }

    Battle.set_modoptions(lobby_id, %{
      "multi_key1" => "multi_value1",
      "multi_key2" => "multi_value2"
    })

    [reply] = _tachyon_recv_until(socket)

    assert reply == %{
             "cmd" => "s.lobby.set_modoptions",
             "lobby_id" => lobby_id,
             "new_options" => %{
               "multi_key1" => "multi_value1",
               "multi_key2" => "multi_value2"
             }
           }

    Battle.remove_modoptions(lobby_id, ["singe_key", "non-existing-key"])
    [reply] = _tachyon_recv_until(socket)

    assert reply == %{
             "cmd" => "s.lobby.remove_modoptions",
             "lobby_id" => lobby_id,
             "keys" => ["singe_key"]
           }

    # Start areas
    Logger.warn(
      "#{__ENV__.file}.#{__ENV__.line} should add, update and remove start areas via the Tachyon command"
    )

    Battle.add_start_area(lobby_id, 1, %{shape: "rectangle", x1: 1, y1: 2, x2: 3, y2: 4})

    [reply] = _tachyon_recv_until(socket)

    assert reply == %{
             "cmd" => "s.lobby.add_start_area",
             "lobby_id" => lobby_id,
             "area_id" => 1,
             "structure" => %{"shape" => "rectangle", "x1" => 1, "y1" => 2, "x2" => 3, "y2" => 4}
           }

    Battle.add_start_area(lobby_id, 1, %{shape: "rectangle", x1: 10, y1: 12, x2: 24, y2: 35})

    [reply] = _tachyon_recv_until(socket)

    assert reply == %{
             "cmd" => "s.lobby.add_start_area",
             "lobby_id" => lobby_id,
             "area_id" => 1,
             "structure" => %{
               "shape" => "rectangle",
               "x1" => 10,
               "y1" => 12,
               "x2" => 24,
               "y2" => 35
             }
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
