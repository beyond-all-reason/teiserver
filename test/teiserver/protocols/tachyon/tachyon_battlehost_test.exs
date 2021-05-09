defmodule Teiserver.Protocols.TachyonBattleHostTest do
  use Central.ServerCase

  import Teiserver.TeiserverTestLib,
    only: [tachyon_auth_setup: 0, _tachyon_send: 2, _tachyon_recv: 1]

  setup do
    %{socket: socket, user: user, pid: pid} = tachyon_auth_setup()
    {:ok, socket: socket, user: user, pid: pid}
  end

  test "battle host", %{socket: socket, pid: pid} do
    # Open the battle
    battle = %{
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

    data = %{cmd: "c.battle.create", battle: battle}
    _tachyon_send(socket, data)
    reply = _tachyon_recv(socket)

    assert Map.has_key?(reply, "battle")
    assert match?(%{"cmd" => "s.battle.create", "result" => "success"}, reply)
    battle = reply["battle"]

    assert battle["name"] == "EU 01 - 123"
    assert battle["map_name"] == "koom valley"

    assert GenServer.call(pid, {:get, :battle_id}) == battle["id"]
    assert GenServer.call(pid, {:get, :battle_host}) == true

    # Now leave the battle, closing it in the process
    data = %{cmd: "c.battle.leave"}
    _tachyon_send(socket, data)
    reply = _tachyon_recv(socket)
    assert match?(%{"cmd" => "s.battle.leave"}, reply)

    assert GenServer.call(pid, {:get, :battle_id}) == nil
    assert GenServer.call(pid, {:get, :battle_host}) == false
  end
end
