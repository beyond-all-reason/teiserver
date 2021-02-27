defmodule Teiserver.TcpServerTest do
  use Central.ServerCase
  import Teiserver.TestLib, only: [raw_setup: 0, _send: 2, _recv: 1, _recv_until: 1, new_user_name: 0]

  setup do
    %{socket: socket} = raw_setup()
    {:ok, socket: socket}
  end

  test "tcp startup and exit", %{socket: socket} do
    password = "X03MO1qnZdYdgyfeuILPmQ=="
    username = new_user_name() <> "_tcp"

    # We expect to be greeted by a welcome message
    reply = _recv(socket)
    assert reply == "TASSERVER 0.38-33-ga5f3b28 * 8201 0\n"

    _send(socket, "REGISTER #{username} #{password} email\n")
    reply = _recv(socket)
    assert reply == "REGISTRATIONACCEPTED\n"

    _send(
      socket,
      "LOGIN #{username} X03MO1qnZdYdgyfeuILPmQ== 0 * LuaLobby Chobby\t1993717506\t0d04a635e200f308\tb sp\n"
    )

    reply = _recv_until(socket)
    [accepted | remainder] = String.split(reply, "\n")
    assert accepted == "ACCEPTED #{username}"

    commands =
      remainder
      |> Enum.map(fn line -> String.split(line, " ") |> hd end)
      |> Enum.uniq()

    assert "MOTD" in commands
    assert "ADDUSER" in commands
    assert "LOGININFOEND" in commands

    _send(socket, "EXIT\n")
    _ = _recv(socket)
    {:error, :closed} = :gen_tcp.recv(socket, 0, 1000)
  end
end
