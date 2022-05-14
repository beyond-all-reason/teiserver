defmodule Teiserver.Protocols.V1.TachyonBattleHostTest do
  use Central.ServerCase
  alias Teiserver.Battle.Lobby

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
    data = %{cmd: "c.lobby.query", query: %{id_list: [lobby_id]}}
    _tachyon_send(socket2, data)
    [reply] = _tachyon_recv(socket2)

    assert reply["cmd"] == "s.lobby.query"
    assert Enum.count(reply["lobbies"]) == 1
    lobby = hd(reply["lobbies"])
    assert lobby["id"] == lobby_id
    assert lobby["players"] == [user2.id]

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
    lobby = hd(reply["lobbies"])
    assert lobby["id"] == lobby_id
    assert lobby["players"] == [user3.id, user2.id]

    # We now have two members, we need to update their statuses
    # reset all socket messages
    _tachyon_recv_until(socket)
    _tachyon_recv_until(socket2)
    _tachyon_recv_until(socket3)

    _tachyon_send(socket2, %{cmd: "c.lobby.update_status", client: %{player: true, team_number: 3, ready: true}})
    [reply2] = _tachyon_recv(socket2)
    [reply3] = _tachyon_recv(socket3)

    assert reply2 == reply3
    assert reply2["cmd"] == "s.lobby.updated_client_battlestatus"
    assert reply2["lobby_id"] == lobby_id
    assert reply2["client"]["player"] == true
    assert reply2["client"]["team_number"] == 3

    # Now leave the lobby, closing it in the process
    _tachyon_recv_until(socket)
    data = %{cmd: "c.lobby.leave"}
    _tachyon_send(socket, data)
    [reply] = _tachyon_recv(socket)
    assert match?(%{"cmd" => "s.lobby.leave"}, reply)

    assert GenServer.call(pid, {:get, :lobby_id}) == nil
    assert GenServer.call(pid, {:get, :lobby_host}) == false
    assert Lobby.get_lobby(lobby_id) == nil
  end
end
