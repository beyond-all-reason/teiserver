defmodule Teiserver.TcpServerTest do
  use Central.ServerCase, async: false

  alias Teiserver.User
  import Teiserver.TestLib,
    only: [raw_setup: 0, _send: 2, _recv: 1, _recv_until: 1, new_user_name: 0]

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
    [agreement_full, agreement_empty, agreement_end | _] = String.split(reply, "\n")
    assert agreement_full == "AGREEMENT A verification code has been sent to your email address. Please read our terms of service and then enter your six digit code below."
    assert agreement_empty == "AGREEMENT "
    assert agreement_end == "AGREEMENTEND"

    # Put in the wrong code
    _send(socket, "CONFIRMAGREEMENT 1111111111111111111\n")
    reply = _recv_until(socket)
    assert reply == "DENIED Incorrect code\n"

    # Put in the correct code
    user = User.get_user_by_name(username)
    _send(socket, "CONFIRMAGREEMENT #{user.verification_code}\n")
    reply = _recv_until(socket)
    assert reply == ""

    _send(
      socket,
      "LOGIN #{username} X03MO1qnZdYdgyfeuILPmQ== 0 * LuaLobby Chobby\t1993717506\t0d04a635e200f308\tb sp\n"
    )
    reply = _recv_until(socket)

    [accepted | remainder] = String.split(reply, "\n")
    assert accepted == "ACCEPTED #{user.name}"

    commands =
      remainder
      |> Enum.map(fn line -> String.split(line, " ") |> hd end)
      |> Enum.uniq()

    assert "MOTD" in commands
    assert "ADDUSER" in commands
    assert "LOGININFOEND" in commands

    # Try sending a multi-part message?
    # Join a chat channel
    _send(socket, "JOIN mpchan\n")
    reply = _recv(socket)
    assert reply =~ "JOIN mpchan\n"
    assert reply =~ "JOINED mpchan #{username}\n"
    assert reply =~ "CHANNELTOPIC mpchan #{username}\n"
    assert reply =~ "CLIENTS mpchan #{username}\n"

    # And send something very long
    msg =
      1..1800
      |> Enum.map(fn _ -> "x" end)
      |> Enum.join("")

    # This is long enough it should trigger a splitting
    _send(socket, "SAY mpchan #{msg}\n")
    reply = _recv(socket)
    assert reply =~ "SAID mpchan #{username} xxxxxxx"

    _send(socket, "EXIT\n")
    _ = _recv(socket)
    {:error, :closed} = :gen_tcp.recv(socket, 0, 1000)
  end
end
