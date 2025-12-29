defmodule Teiserver.SpringTcpServerTest do
  use Teiserver.ServerCase, async: false

  require Logger

  import Mock

  import Teiserver.TeiserverTestLib,
    only: [
      raw_setup: 1,
      _send_raw: 2,
      _recv_raw: 1,
      _recv_until: 1,
      auth_setup: 1,
      new_user: 0,
      start_spring_server: 1
    ]

  alias Teiserver.Account.UserCacheLib
  alias Teiserver.{Account, Client, Room, TeiserverTestLib}

  setup :start_spring_server

  setup(context) do
    Teiserver.TeiserverTestLib.start_coordinator!()

    %{socket: socket} = raw_setup(context)
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
    username = "test_user_tcpnew"

    # We expect to be greeted by a welcome message
    reply = _recv_raw(socket)
    assert reply == "TASSERVER 0.38-33-ga5f3b28 * 8201 0\n"

    _send_raw(socket, "REGISTER #{username} #{password} email@e.e\n")
    reply = _recv_raw(socket)
    assert reply == "REGISTRATIONACCEPTED\n"

    user = UserCacheLib.get_user_by_name(username)
    query = "UPDATE account_users SET inserted_at = '2020-01-01 01:01:01' WHERE id = #{user.id}"
    Ecto.Adapters.SQL.query(Repo, query, [])
    Teiserver.Account.UserCacheLib.recache_user(user.id)

    _send_raw(
      socket,
      "LOGIN #{username} X03MO1qnZdYdgyfeuILPmQ== 0 * LuaLobby Chobby\t1993717506 0d04a635e200f308\tb sp\n"
    )

    reply = _recv_until(socket)
    [agreement_full, agreement_empty, agreement_end | _] = String.split(reply, "\n")

    assert agreement_full ==
             "AGREEMENT A verification code has been sent to your email address. Please read our terms of service at https://beyondallreason.info/privacy_policy and the code of conduct at https://www.beyondallreason.info/code-of-conduct. Then enter your six digit code below if you agree to the terms."

    assert agreement_empty == "AGREEMENT "
    assert agreement_end == "AGREEMENTEND"

    # Put in the wrong code
    _send_raw(socket, "CONFIRMAGREEMENT 1111111111111111111\n")
    reply = _recv_until(socket)
    assert reply == "DENIED Incorrect code\n"

    # Put in the correct code
    code = Account.get_user_stat_data(user.id)["verification_code"]
    _send_raw(socket, "CONFIRMAGREEMENT #{code}\n")

    reply = _recv_until(socket)
    assert reply =~ "ACCEPTED #{user.name}\n"

    [accepted | remainder] = String.split(reply, "\n")
    assert accepted == "ACCEPTED #{user.name}"

    commands =
      remainder
      |> Enum.map(fn line -> String.split(line, " ") |> hd() end)
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
      |> Enum.map_join("", fn _ -> "x" end)

    # This is long enough it should trigger a splitting
    _send_raw(socket, "SAY mpchan #{msg}\n")
    reply = _recv_raw(socket)
    assert reply =~ "SAID mpchan #{username} xxxxxxx"

    _send_raw(socket, "EXIT\n")
    _ = _recv_raw(socket)
    {:error, :closed} = :gen_tcp.recv(socket, 0, 1000)
  end

  test "when redirect site config is set sends REDIRECT and closes", context do
    redirect_ip = "1.2.3.4"
    redirect_port = TeiserverTestLib.get_listener_port(:tcp)

    with_mock(
      Teiserver.Config,
      [:passthrough],
      get_site_config_cache: fn
        "system.Redirect url" -> redirect_ip
        other -> passthrough([other])
      end
    ) do
      %{socket: socket} = raw_setup(context)

      assert _recv_raw(socket) == "REDIRECT #{redirect_ip} #{redirect_port}\n"
      {:error, :closed} = :gen_tcp.recv(socket, 0, 1000)
    end
  end

  # NOTE: All needs_attention tests in this module fail because of the coordinator state being shared between tests
  @tag :needs_attention
  test "bad sequences", context do
    %{socket: socket, user: user} = auth_setup(context)
    client = Client.get_client_by_name(user.name)
    tcp_pid = client.tcp_pid
    coordinator_userid = Teiserver.Coordinator.get_coordinator_userid()

    # Should be no users but ourselves
    :timer.sleep(300)

    assert GenServer.call(tcp_pid, {:get, :known_users}) == %{
             user.id => %{lobby_id: nil},
             coordinator_userid => %{lobby_id: nil}
           }

    %{socket: s1, user: u1} = auth_setup(context)
    %{socket: _s2, user: u2} = auth_setup(context)
    %{socket: _s3, user: u3} = auth_setup(context)

    u1_client = %{
      userid: u1.id,
      name: u1.name,
      country: "??",
      lobby_client: "LuaLobby Chobby",
      rank: 0,
      in_game: false,
      away: false,
      moderator: false,
      bot: false
    }

    # They should now all be known
    assert GenServer.call(tcp_pid, {:get, :known_users}) == %{
             user.id => %{lobby_id: nil},
             u1.id => %{lobby_id: nil},
             u2.id => %{lobby_id: nil},
             u3.id => %{lobby_id: nil},
             coordinator_userid => %{lobby_id: nil}
           }

    # Flush the message queues
    _ = _recv_raw(socket)
    _ = _recv_raw(s1)
    # _ = _recv_raw(s2)
    # _ = _recv_raw(s3)

    # Lets start with the same user logging in multiple times
    # first ourselves, shouldn't see anything here
    send(tcp_pid, %{channel: "client_inout", event: :login, client: %{userid: user.id}})
    r = _recv_raw(socket)
    assert r == :timeout

    # Now u1, already logged in
    send(tcp_pid, %{channel: "client_inout", event: :login, client: u1_client})
    r = _recv_raw(socket)
    assert r == :timeout

    # Log out u1, should work
    send(tcp_pid, %{channel: "client_inout", event: :disconnect, userid: u1.id})
    r = _recv_raw(socket)
    assert r == "REMOVEUSER #{u1.name}\n"

    assert GenServer.call(tcp_pid, {:get, :known_users}) == %{
             user.id => %{lobby_id: nil},
             u2.id => %{lobby_id: nil},
             u3.id => %{lobby_id: nil},
             coordinator_userid => %{lobby_id: nil}
           }

    # Repeat, should not do anything
    send(tcp_pid, %{channel: "client_inout", event: :disconnect, userid: u1.id})
    r = _recv_raw(socket)
    assert r == :timeout

    assert GenServer.call(tcp_pid, {:get, :known_users}) == %{
             user.id => %{lobby_id: nil},
             u2.id => %{lobby_id: nil},
             u3.id => %{lobby_id: nil},
             coordinator_userid => %{lobby_id: nil}
           }

    # Logs back in
    send(tcp_pid, %{channel: "client_inout", event: :login, client: u1_client})
    r = _recv_raw(socket)
    assert r == "ADDUSER #{u1.name} ?? #{u1.id} LuaLobby Chobby\nCLIENTSTATUS #{u1.name} 0\n"

    assert GenServer.call(tcp_pid, {:get, :known_users}) == %{
             user.id => %{lobby_id: nil},
             u1.id => %{lobby_id: nil},
             u2.id => %{lobby_id: nil},
             u3.id => %{lobby_id: nil},
             coordinator_userid => %{lobby_id: nil}
           }

    # ---- BATTLES ----
    lobby_id = 111
    assert GenServer.call(tcp_pid, {:get, :known_battles}) == []
    # send(tcp_pid, {:add_user_to_battle, u1.id, lobby_id, "script_password"})
    send(tcp_pid, %{
      channel: "teiserver_global_user_updates",
      event: :joined_lobby,
      client: u1_client,
      lobby_id: lobby_id,
      script_password: "script_password"
    })

    r = _recv_until(socket)
    assert r == "CLIENTSTATUS #{u1.name} 0\nJOINEDBATTLE #{lobby_id} #{u1.name}\n"

    assert GenServer.call(tcp_pid, {:get, :known_users}) == %{
             user.id => %{lobby_id: nil},
             u1.id => %{lobby_id: lobby_id},
             u2.id => %{lobby_id: nil},
             u3.id => %{lobby_id: nil},
             coordinator_userid => %{lobby_id: nil}
           }

    # Duplicate user in battle
    send(tcp_pid, %{
      channel: "teiserver_global_user_updates",
      event: :joined_lobby,
      client: u1_client,
      lobby_id: lobby_id,
      script_password: "script_password"
    })

    r = _recv_raw(socket)
    assert r == "CLIENTSTATUS #{u1.name} 0\n"

    assert GenServer.call(tcp_pid, {:get, :known_users}) == %{
             user.id => %{lobby_id: nil},
             u1.id => %{lobby_id: lobby_id},
             u2.id => %{lobby_id: nil},
             u3.id => %{lobby_id: nil},
             coordinator_userid => %{lobby_id: nil}
           }

    # User moves to a different battle (without leave command)
    send(tcp_pid, %{
      channel: "teiserver_global_user_updates",
      event: :joined_lobby,
      client: u1_client,
      lobby_id: lobby_id + 1,
      script_password: "script_password"
    })

    :timer.sleep(250)
    r = _recv_raw(socket)

    # Run on it's own it passes, run as part of the greater tests it sometimes fails
    assert GenServer.call(tcp_pid, {:get, :known_users}) == %{
             user.id => %{lobby_id: nil},
             u1.id => %{lobby_id: lobby_id + 1},
             u2.id => %{lobby_id: nil},
             u3.id => %{lobby_id: nil},
             coordinator_userid => %{lobby_id: nil}
           }

    assert r == "CLIENTSTATUS #{u1.name} 0\nJOINEDBATTLE #{lobby_id + 1} #{u1.name}\n"
    # credo:disable-for-next-line Credo.Check.Design.TagTODO
    # TODO: Find out why the below doesn't happen
    # assert r == "LEFTBATTLE #{lobby_id} #{u1.name}\nJOINEDBATTLE #{lobby_id + 1} #{u1.name}\n"

    # Same battle again
    send(tcp_pid, %{
      channel: "teiserver_global_user_updates",
      event: :joined_lobby,
      client: u1_client,
      lobby_id: lobby_id + 1,
      script_password: "script_password"
    })

    r = _recv_raw(socket)
    assert r == "CLIENTSTATUS #{u1.name} 0\n"

    # Log the user out and then get them to join a battle
    send(tcp_pid, %{channel: "client_inout", event: :disconnect, userid: u1.id})
    r = _recv_raw(socket)
    assert r == "REMOVEUSER #{u1.name}\n"

    # Now they join, should get a login and then a join battle command
    send(tcp_pid, %{
      channel: "teiserver_global_user_updates",
      event: :joined_lobby,
      client: u1_client,
      lobby_id: lobby_id + 1,
      script_password: "script_password"
    })

    :timer.sleep(500)
    r = _recv_raw(socket)

    # credo:disable-for-next-line Credo.Check.Design.TagTODO
    # TODO: Sometimes this fails for no apparent reason, unable to reproduce since the above
    # 500 sleep call but I seem to recall that previously not helping
    expected =
      "ADDUSER #{u1.name} ?? #{u1.id} LuaLobby Chobby\nCLIENTSTATUS #{u1.name} 0\nJOINEDBATTLE #{lobby_id + 1} #{u1.name}\n"

    assert r == expected

    # ---- Chat rooms ----
    send(tcp_pid, {:add_user_to_room, u1.id, "roomname"})
    r = _recv_raw(socket)
    assert r == "JOINED roomname #{u1.name}\n"

    send(tcp_pid, {:add_user_to_room, u1.id, "roomname"})
    r = _recv_raw(socket)
    assert r == :timeout

    # Remove
    send(tcp_pid, {:remove_user_from_room, u1.id, "roomname"})
    r = _recv_raw(socket)
    assert r == "LEFT roomname #{u1.name}\n"

    send(tcp_pid, {:remove_user_from_room, u1.id, "roomname"})
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

  @tag :needs_attention
  # this test is quite annoying because, when running only this module, it passes
  # but when ran with other tests around, it'll fail
  # the fault likely lies elsewhere, good luck to the brave soul tackling that
  @tag :needs_attention
  test "dud users mode", context do
    # Here we're testing if the user isn't even known
    non_user = new_user()
    %{user: dud} = auth_setup(context)
    %{socket: socket, user: user} = auth_setup(context)

    client = Client.get_client_by_name(user.name)
    tcp_pid = client.tcp_pid

    coordinator_id = Client.get_client_by_name("Coordinator").userid

    # --- User logs out
    # At first it should be user, dud and coordinator
    known = :sys.get_state(tcp_pid) |> Map.get(:known_users)
    assert Map.keys(known) == [coordinator_id, dud.id, user.id]

    send(tcp_pid, %{channel: "client_inout", event: :disconnect, userid: dud.id})
    r = _recv_until(socket)
    assert r == "REMOVEUSER #{dud.name}\n"
    known = :sys.get_state(tcp_pid) |> Map.get(:known_users)
    assert Map.keys(known) == [coordinator_id, user.id]

    # Now what if they log out again?
    send(tcp_pid, %{channel: "client_inout", event: :disconnect, userid: dud.id})
    r = _recv_until(socket)
    assert r == ""
    known = :sys.get_state(tcp_pid) |> Map.get(:known_users)
    assert Map.keys(known) == [coordinator_id, user.id]

    # Now what if non_user is logged out (they were never logged in to start with)
    send(tcp_pid, %{channel: "client_inout", event: :disconnect, userid: non_user.id})
    r = _recv_until(socket)
    assert r == ""
    known = :sys.get_state(tcp_pid) |> Map.get(:known_users)
    assert Map.keys(known) == [coordinator_id, user.id]

    # Now what if we find a userid that they don't have?
    send(tcp_pid, %{channel: "client_inout", event: :disconnect, userid: 0})
    r = _recv_until(socket)
    assert r == ""
    known = :sys.get_state(tcp_pid) |> Map.get(:known_users)
    assert Map.keys(known) == [coordinator_id, user.id]

    # ---- Chat rooms ----
    # Join chat room
    send(tcp_pid, %{channel: "client_inout", event: :disconnect, userid: dud.id})
    _recv_until(socket)
    known = :sys.get_state(tcp_pid) |> Map.get(:known_users)
    assert Map.keys(known) == [coordinator_id, user.id]

    send(tcp_pid, {:add_user_to_room, dud.id, "roomname"})
    r = _recv_until(socket)

    assert r ==
             "ADDUSER #{dud.name} ?? #{dud.id} LuaLobby Chobby\nCLIENTSTATUS #{dud.name} 0\nJOINED roomname #{dud.name}\n"

    # Now the non-user, should be nothing since they're not actually logged in
    send(tcp_pid, {:add_user_to_room, non_user.id, "roomname"})
    r = _recv_until(socket)
    assert r == ""

    # Leave chat room
    send(tcp_pid, %{channel: "client_inout", event: :disconnect, userid: dud.id})
    _recv_until(socket)
    send(tcp_pid, {:remove_user_from_room, dud.id, "roomname"})
    r = _recv_until(socket)
    assert r == ""

    # Now the non-user, should be nothing since they're not actually logged in
    send(tcp_pid, {:remove_user_from_room, non_user.id, "roomname"})
    r = _recv_until(socket)
    assert r == ""

    # Send chat message
    send(tcp_pid, %{channel: "client_inout", event: :disconnect, userid: dud.id})
    _recv_until(socket)
    send(tcp_pid, {:direct_message, dud.id, "msgmsg"})
    r = _recv_until(socket)

    assert r ==
             "ADDUSER #{dud.name} ?? #{dud.id} LuaLobby Chobby\nCLIENTSTATUS #{dud.name} 0\nSAIDPRIVATE #{dud.name} msgmsg\n"

    send(tcp_pid, %{channel: "client_inout", event: :disconnect, userid: dud.id})
    _recv_until(socket)
    send(tcp_pid, {:new_message, dud.id, "roomname", "msgmsg"})
    r = _recv_until(socket)

    assert r ==
             "ADDUSER #{dud.name} ?? #{dud.id} LuaLobby Chobby\nCLIENTSTATUS #{dud.name} 0\nSAID roomname #{dud.name} msgmsg\n"

    send(tcp_pid, %{channel: "client_inout", event: :disconnect, userid: dud.id})
    _recv_until(socket)
    send(tcp_pid, {:new_message_ex, dud.id, "roomname", "msgmsg"})
    r = _recv_until(socket)

    assert r ==
             "ADDUSER #{dud.name} ?? #{dud.id} LuaLobby Chobby\nCLIENTSTATUS #{dud.name} 0\nSAIDEX roomname #{dud.name} msgmsg\n"

    # Now the non-user, should get a whole new adding of a user, even though that user isn't logged in
    send(tcp_pid, {:direct_message, non_user.id, "msgmsg"})
    r = _recv_until(socket)

    assert r ==
             "ADDUSER #{non_user.name}  #{non_user.id} \nCLIENTSTATUS #{non_user.name} 0\nSAIDPRIVATE #{non_user.name} msgmsg\n"

    assert Account.get_client_by_id(non_user.id) == nil

    send(tcp_pid, {:new_message, non_user.id, "roomname", "msgmsg"})
    r = _recv_until(socket)
    assert r == "SAID roomname #{non_user.name} msgmsg\n"
    assert Account.get_client_by_id(non_user.id) == nil

    send(tcp_pid, {:new_message_ex, non_user.id, "roomname", "msgmsg"})
    r = _recv_until(socket)
    assert r == "SAIDEX roomname #{non_user.name} msgmsg\n"
    assert Account.get_client_by_id(non_user.id) == nil

    # Join room stuff
    Room.get_or_make_room("dud_room", dud.id)
    Room.add_user_to_room(dud.id, "dud_room")
    send(tcp_pid, %{channel: "client_inout", event: :disconnect, userid: dud.id})
    state = :sys.get_state(tcp_pid)
    _recv_until(socket)

    # Join a room when we don't know about dud_user
    Teiserver.Protocols.SpringOut.do_join_room(state, "dud_room")
    r = _recv_until(socket)

    assert r ==
             "JOIN dud_room\nJOINED dud_room #{user.name}\nCHANNELTOPIC dud_room #{dud.name}\nADDUSER #{dud.name} ?? #{dud.id} LuaLobby Chobby\nCLIENTSTATUS #{dud.name} 0\nCLIENTS dud_room #{user.name} #{dud.name}\n"
  end
end
