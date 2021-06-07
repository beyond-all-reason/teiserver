defmodule Teiserver.TcpServerTest do
  use Central.ServerCase, async: false

  alias Teiserver.User
  alias Teiserver.Client
  require Logger

  import Teiserver.TeiserverTestLib,
    only: [raw_setup: 0, _send_raw: 2, _recv_raw: 1, _recv_until: 1, new_user_name: 0, auth_setup: 0]

  setup do
    %{socket: socket} = raw_setup()
    {:ok, socket: socket}
  end

  # test "ssl upgrade", %{socket: socket} do
  #   reply = _recv_raw(socket)
  #   assert reply == "TASSERVER 0.38-33-ga5f3b28 * 8201 0\n"

  #   _send_raw(socket, "STLS\n")
  #   reply = _recv_raw(socket)
  #   assert reply == "OK cmd=STLS\n"

  #   :timer.sleep(5500)

  #   _send_raw(socket, "EXIT\n")
  #   _ = _recv_raw(socket)
  # end

  test "tcp startup and exit", %{socket: socket} do
    password = "X03MO1qnZdYdgyfeuILPmQ=="
    username = new_user_name() <> "_tcp"

    # We expect to be greeted by a welcome message
    reply = _recv_raw(socket)
    assert reply == "TASSERVER 0.38-33-ga5f3b28 * 8201 0\n"

    _send_raw(socket, "REGISTER #{username} #{password} email\n")
    reply = _recv_raw(socket)
    assert reply == "REGISTRATIONACCEPTED\n"

    _send_raw(
      socket,
      "LOGIN #{username} X03MO1qnZdYdgyfeuILPmQ== 0 * LuaLobby Chobby\t1993717506\t0d04a635e200f308\tb sp\n"
    )

    reply = _recv_until(socket)
    [agreement_full, agreement_empty, agreement_end | _] = String.split(reply, "\n")

    assert agreement_full ==
             "AGREEMENT User agreement goes here."

    assert agreement_empty == "AGREEMENT "
    assert agreement_end == "AGREEMENTEND"

    # Put in the wrong code
    _send_raw(socket, "CONFIRMAGREEMENT 1111111111111111111\n")
    reply = _recv_until(socket)
    assert reply == "DENIED Incorrect code\n"

    # Put in the correct code
    user = User.get_user_by_name(username)
    _send_raw(socket, "CONFIRMAGREEMENT #{user.verification_code}\n")

    reply = _recv_until(socket)
    assert reply =~ "ACCEPTED #{user.name}\n"

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
    _send_raw(socket, "JOIN mpchan\n")
    reply = _recv_raw(socket)
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
    _send_raw(socket, "SAY mpchan #{msg}\n")
    reply = _recv_raw(socket)
    assert reply =~ "SAID mpchan #{username} xxxxxxx"

    _send_raw(socket, "EXIT\n")
    _ = _recv_raw(socket)
    {:error, :closed} = :gen_tcp.recv(socket, 0, 1000)
  end

  test "bad sequences" do
    %{socket: socket, user: user} = auth_setup()
    client = Client.get_client_by_name(user.name)
    pid = client.pid

    # Should be no users but ourselves
    assert GenServer.call(pid, {:get, :known_users}) == %{
      user.id => %{battle_id: nil, userid: user.id}
    }

    %{socket: s1, user: u1} = auth_setup()
    %{socket: _s2, user: u2} = auth_setup()
    %{socket: _s3, user: u3} = auth_setup()

    # They should now all be known
    assert GenServer.call(pid, {:get, :known_users}) == %{
      user.id => %{battle_id: nil, userid: user.id},
      u1.id => %{battle_id: nil, userid: u1.id},
      u2.id => %{battle_id: nil, userid: u2.id},
      u3.id => %{battle_id: nil, userid: u3.id},
    }

    # Flush the message queues
    _ = _recv_raw(socket)
    _ = _recv_raw(s1)
    # _ = _recv_raw(s2)
    # _ = _recv_raw(s3)

    # Enable logging
    # send(pid, {:put, :extra_logging, true})

    # Lets start with the same user logging in multiple times
    # first ourselves, shouldn't see anything here
    send(pid, {:user_logged_in, user.id})
    r = _recv_raw(socket)
    assert r == :timeout

    # Now u1, already logged in
    send(pid, {:user_logged_in, u1.id})
    r = _recv_raw(socket)
    assert r == :timeout

    # Log out u1, should work
    send(pid, {:user_logged_out, u1.id, u1.name})
    r = _recv_raw(socket)
    assert r == "REMOVEUSER #{u1.name}\n"

    assert GenServer.call(pid, {:get, :known_users}) == %{
      user.id => %{battle_id: nil, userid: user.id},
      u2.id => %{battle_id: nil, userid: u2.id},
      u3.id => %{battle_id: nil, userid: u3.id},
    }

    # Repeat, should not do anything
    send(pid, {:user_logged_out, u1.id, u1.name})
    r = _recv_raw(socket)
    assert r == :timeout

    assert GenServer.call(pid, {:get, :known_users}) == %{
      user.id => %{battle_id: nil, userid: user.id},
      u2.id => %{battle_id: nil, userid: u2.id},
      u3.id => %{battle_id: nil, userid: u3.id},
    }

    # Logs back in
    send(pid, {:user_logged_in, u1.id})
    r = _recv_raw(socket)
    assert r == "ADDUSER #{u1.name} ?? 0 #{u1.id} LuaLobby Chobby\nCLIENTSTATUS #{u1.name} 0\n"

    assert GenServer.call(pid, {:get, :known_users}) == %{
      user.id => %{battle_id: nil, userid: user.id},
      u1.id => %{battle_id: nil, userid: u1.id},
      u2.id => %{battle_id: nil, userid: u2.id},
      u3.id => %{battle_id: nil, userid: u3.id},
    }

    # ---- BATTLES ----
    battle_id = 111
    assert GenServer.call(pid, {:get, :known_battles}) == []
    send(pid, {:add_user_to_battle, u1.id, battle_id, "script_password"})
    r = _recv_raw(socket)
    assert r == "JOINEDBATTLE #{battle_id} #{u1.name}\n"

    assert GenServer.call(pid, {:get, :known_users}) == %{
      user.id => %{battle_id: nil, userid: user.id},
      u1.id => %{battle_id: battle_id, userid: u1.id},
      u2.id => %{battle_id: nil, userid: u2.id},
      u3.id => %{battle_id: nil, userid: u3.id},
    }

    # Duplicate user in battle
    send(pid, {:add_user_to_battle, u1.id, battle_id, "script_password"})
    r = _recv_raw(socket)
    assert r == :timeout

    assert GenServer.call(pid, {:get, :known_users}) == %{
      user.id => %{battle_id: nil, userid: user.id},
      u1.id => %{battle_id: battle_id, userid: u1.id},
      u2.id => %{battle_id: nil, userid: u2.id},
      u3.id => %{battle_id: nil, userid: u3.id},
    }

    # User moves to a different battle (without leave command)
    send(pid, {:add_user_to_battle, u1.id, battle_id + 1, "script_password"})
    :timer.sleep(250)
    r = _recv_raw(socket)

    # Run on it's own it passes, run as part of the greater tests it sometimes fails
    assert GenServer.call(pid, {:get, :known_users}) == %{
      user.id => %{battle_id: nil, userid: user.id},
      u1.id => %{battle_id: battle_id + 1, userid: u1.id},
      u2.id => %{battle_id: nil, userid: u2.id},
      u3.id => %{battle_id: nil, userid: u3.id},
    }
    assert r == "JOINEDBATTLE #{battle_id + 1} #{u1.name}\n"
    # TODO: Find out why the below doesn't happen
    # assert r == "LEFTBATTLE #{battle_id} #{u1.name}\nJOINEDBATTLE #{battle_id + 1} #{u1.name}\n"

    # Same battle again
    send(pid, {:add_user_to_battle, u1.id, battle_id + 1, "script_password"})
    r = _recv_raw(socket)
    assert r == :timeout

    # Log the user out and then get them to join a battle
    send(pid, {:user_logged_out, u1.id, u1.name})
    r = _recv_raw(socket)
    assert r == "REMOVEUSER #{u1.name}\n"

    # Now they join, should get a login and then a join battle command
    send(pid, {:add_user_to_battle, u1.id, battle_id + 1, "script_password"})
    r = _recv_raw(socket)

    assert r ==
             "ADDUSER #{u1.name} ?? 0 #{u1.id} LuaLobby Chobby\nCLIENTSTATUS #{u1.name} 0\nJOINEDBATTLE #{
               battle_id + 1
             } #{u1.name}\n"

    # ---- Chat rooms ----
    send(pid, {:add_user_to_room, u1.id, "roomname"})
    r = _recv_raw(socket)
    assert r == "JOINED roomname #{u1.name}\n"

    send(pid, {:add_user_to_room, u1.id, "roomname"})
    r = _recv_raw(socket)
    assert r == :timeout

    # Remove
    send(pid, {:remove_user_from_room, u1.id, "roomname"})
    r = _recv_raw(socket)
    assert r == "LEFT roomname #{u1.name}\n"

    send(pid, {:remove_user_from_room, u1.id, "roomname"})
    r = _recv_raw(socket)
    assert r == :timeout

    _send_raw(socket, "EXIT\n")
    _send_raw(s1, "EXIT\n")
    # _send_raw(s2, "EXIT\n")
    # _send_raw(s3, "EXIT\n")
    _ = _recv_raw(socket)
    _ = _recv_raw(s1)
    # _ = _recv_raw(s2)
    # _ = _recv_raw(s3)
  end
end
