defmodule Teiserver.TcpServerTest do
  use Central.ServerCase, async: false

  alias Teiserver.User
  alias Teiserver.Client
  require Logger

  import Teiserver.TestLib,
    only: [raw_setup: 0, _send: 2, _recv: 1, _recv_until: 1, new_user_name: 0, auth_setup: 0]

  setup do
    %{socket: socket} = raw_setup()
    {:ok, socket: socket}
  end

  # test "ssl upgrade", %{socket: socket} do
  #   reply = _recv(socket)
  #   assert reply == "TASSERVER 0.38-33-ga5f3b28 * 8201 0\n"

  #   _send(socket, "STLS\n")
  #   reply = _recv(socket)
  #   assert reply == "OK cmd=STLS\n"

  #   :timer.sleep(5500)

  #   _send(socket, "EXIT\n")
  #   _ = _recv(socket)
  # end

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

    assert agreement_full ==
             "AGREEMENT A verification code has been sent to your email address. Please read our terms of service and then enter your six digit code below."

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

  test "bad sequences" do
    %{socket: socket, user: user} = auth_setup()
    %{socket: s1, user: u1} = auth_setup()
    # %{socket: s2, user: u2} = auth_setup()
    # %{socket: s3, user: u3} = auth_setup()

    # Flush the message queues
    _ = _recv(socket)
    _ = _recv(s1)
    # _ = _recv(s2)
    # _ = _recv(s3)

    client = Client.get_client_by_name(user.name)
    pid = client.pid

    # Enable logging
    # send(pid, {:put, :extra_logging, true})

    # Lets start with the same user logging in multiple times
    # first ourselves, shouldn't see anything here
    send(pid, {:user_logged_in, user.id})
    r = _recv(socket)
    assert r == :timeout

    # Now u1, already logged in
    send(pid, {:user_logged_in, u1.id})
    r = _recv(socket)
    assert r == :timeout

    # Log out u1, should work
    send(pid, {:user_logged_out, u1.id, u1.name})
    r = _recv(socket)
    assert r == "REMOVEUSER #{u1.name}\n"

    # Repeat, should not do anything
    send(pid, {:user_logged_out, u1.id, u1.name})
    r = _recv(socket)
    assert r == :timeout

    # Logs back in
    send(pid, {:user_logged_in, u1.id})
    r = _recv(socket)
    assert r == "ADDUSER #{u1.name} ?? 0 #{u1.id} LuaLobby Chobby\nCLIENTSTATUS #{u1.name} 0\n"

    # ---- BATTLES ----
    battle_id = 111
    send(pid, {:add_user_to_battle, u1.id, battle_id})
    r = _recv(socket)
    assert r == "JOINEDBATTLE #{battle_id} #{u1.name}\n"

    # Duplicate user in battle
    send(pid, {:add_user_to_battle, u1.id, battle_id})
    r = _recv(socket)
    assert r == :timeout

    # User moves to a different battle (without leave command)
    send(pid, {:add_user_to_battle, u1.id, battle_id + 1})
    r = _recv(socket)
    assert r == "LEFTBATTLE #{battle_id} #{u1.name}\nJOINEDBATTLE #{battle_id + 1} #{u1.name}\n"

    # Same battle again
    send(pid, {:add_user_to_battle, u1.id, battle_id + 1})
    r = _recv(socket)
    assert r == :timeout

    # Log the user out and then get them to join a battle
    send(pid, {:user_logged_out, u1.id, u1.name})
    r = _recv(socket)
    assert r == "REMOVEUSER #{u1.name}\n"

    # Now they join, should get a login and then a join battle command
    send(pid, {:add_user_to_battle, u1.id, battle_id + 1})
    r = _recv(socket)

    assert r ==
             "ADDUSER #{u1.name} ?? 0 #{u1.id} LuaLobby Chobby\nCLIENTSTATUS #{u1.name} 0\nJOINEDBATTLE #{
               battle_id + 1
             } #{u1.name}\n"

    # ---- Chat rooms ----
    send(pid, {:add_user_to_room, u1.id, "roomname"})
    r = _recv(socket)
    assert r == "JOINED roomname #{u1.name}\n"

    send(pid, {:add_user_to_room, u1.id, "roomname"})
    r = _recv(socket)
    assert r == :timeout

    # Remove
    send(pid, {:remove_user_from_room, u1.id, "roomname"})
    r = _recv(socket)
    assert r == "LEFT roomname #{u1.name}\n"

    send(pid, {:remove_user_from_room, u1.id, "roomname"})
    r = _recv(socket)
    assert r == :timeout

    _send(socket, "EXIT\n")
    _send(s1, "EXIT\n")
    # _send(s2, "EXIT\n")
    # _send(s3, "EXIT\n")
    _ = _recv(socket)
    _ = _recv(s1)
    # _ = _recv(s2)
    # _ = _recv(s3)
  end
end
