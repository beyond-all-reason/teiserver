defmodule Teiserver.TcpServerTest do
  use ExUnit.Case
  import Teiserver.TestLib, only: [raw_setup: 0, _send: 2, _recv: 1]
  
  setup do
    %{socket: socket} = raw_setup()
    {:ok, socket: socket}
  end

  test "tcp startup and exit", %{socket: socket} do
    # We expect to be greeted by a welcome message
    reply = _recv(socket)
    assert reply == "TASSERVER 0.38-33-ga5f3b28 * 8201 0\n"

    _send(socket, "LOGIN TestUser X03MO1qnZdYdgyfeuILPmQ== 0 * LuaLobby Chobby\t1993717506\t0d04a635e200f308\tb sp\n")
    reply = _recv(socket)
    [accepted | remainder] = String.split(reply, "\n")
    assert accepted == "ACCEPTED TestUser"

    commands = remainder
    |> Enum.map(fn line -> String.split(line, " ") |> hd end)
    |> Enum.uniq

    assert commands == ["MOTD", "ADDUSER", "BATTLEOPENED", "UPDATEBATTLEINFO", "JOINEDBATTLE", "LOGININFOEND", ""]

    _send(socket, "EXIT\n")
    {:error, :closed} = :gen_tcp.recv(socket, 0, 1000)
  end
end