defmodule Teiserver.Protocols.TachyonBattleHostTest do
  use Central.ServerCase
  alias Teiserver.Battle

  import Teiserver.TeiserverTestLib,
    only: [tachyon_auth_setup: 0, _tachyon_send: 2, _tachyon_recv: 1]

  setup do
    %{socket: socket, user: user, pid: pid} = tachyon_auth_setup()
    {:ok, socket: socket, user: user, pid: pid}
  end

  test "battle host", %{socket: socket, pid: pid} do
    # Open the battle
    battle_data = %{
      cmd: "c.battle.create",
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

    data = %{cmd: "c.battle.create", battle: battle_data}
    _tachyon_send(socket, data)
    reply = _tachyon_recv(socket)

    assert Map.has_key?(reply, "battle")
    assert match?(%{"cmd" => "s.battle.create", "result" => "success"}, reply)
    battle = reply["battle"]

    assert battle["name"] == "EU 01 - 123"
    assert battle["map_name"] == "koom valley"
    battle_id = battle["id"]

    assert GenServer.call(pid, {:get, :battle_id}) == battle_id
    assert GenServer.call(pid, {:get, :battle_host}) == true
    assert Battle.get_battle!(battle_id) != nil

    # Now create a user to join the battle
    %{socket: socket2, user: user2, pid: pid2} = tachyon_auth_setup()
    %{socket: socket3, user: user3} = tachyon_auth_setup()

    # Bad password
    data = %{cmd: "c.battle.join", battle_id: battle_id}
    _tachyon_send(socket2, data)
    reply = _tachyon_recv(socket2)

    assert reply == %{
      "cmd" => "s.battle.join",
      "result" => "failure",
      "reason" => "Invalid password"
    }

    # Good password
    # We send from both users to test for a bug found when making the agent system
    # where two messages queued up might not be decoded correctly
    data = %{cmd: "c.battle.join", battle_id: battle_id, password: "password2"}
    _tachyon_send(socket2, data)
    _tachyon_send(socket3, data)
    reply = _tachyon_recv(socket2)

    assert reply == %{
      "cmd" => "s.battle.join",
      "result" => "waiting_for_host"
    }

    # Host is expecting to see a request
    reply = _tachyon_recv(socket)
    assert reply == %{
      "cmd" => "s.battle.request_to_join",
      "userid" => user2.id
    }

    # Here should be the next request
    reply = _tachyon_recv(socket)
    assert reply == %{
      "cmd" => "s.battle.request_to_join",
      "userid" => user3.id
    }

    # Host can reject
    data = %{cmd: "c.battle.respond_to_join_request", userid: user2.id, response: "reject", reason: "reason given"}
    _tachyon_send(socket, data)
    reply = _tachyon_recv(socket2)

    # Reject user3 at the same time
    data = %{cmd: "c.battle.respond_to_join_request", userid: user3.id, response: "reject", reason: "reason given"}
    _tachyon_send(socket, data)

    assert reply == %{
      "cmd" => "s.battle.join_response",
      "result" => "reject",
      "reason" => "reason given"
    }

    # Now request again but this time accept
    data = %{cmd: "c.battle.join", battle_id: battle_id, password: "password2"}
    _tachyon_send(socket2, data)
    _tachyon_recv(socket2)
    _tachyon_recv(socket)

    assert GenServer.call(pid2, {:get, :battle_id}) == nil

    data = %{cmd: "c.battle.respond_to_join_request", userid: user2.id, response: "approve"}
    _tachyon_send(socket, data)
    reply = _tachyon_recv(socket2)

    assert reply["cmd"] == "s.battle.join_response"
    assert reply["result"] == "approve"
    assert reply["battle"]["id"] == battle_id

    assert GenServer.call(pid2, {:get, :battle_id}) == battle_id




    # # Expecting a request to join here
    # data = %{cmd: "c.battle.join", battle_id: battle_id}
    # _tachyon_send(socket2, data)
    # reply = _tachyon_recv(socket2)

    # # Lets see what happens now
    # reply = _tachyon_recv(socket2)
    # IO.puts ""
    # IO.inspect reply
    # IO.puts ""

    # Now leave the battle, closing it in the process
    data = %{cmd: "c.battle.leave"}
    _tachyon_send(socket, data)
    reply = _tachyon_recv(socket)
    assert match?(%{"cmd" => "s.battle.leave"}, reply)

    assert GenServer.call(pid, {:get, :battle_id}) == nil
    assert GenServer.call(pid, {:get, :battle_host}) == false
    assert Battle.get_battle!(battle_id) == nil
  end
end
