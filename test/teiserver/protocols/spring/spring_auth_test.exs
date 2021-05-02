defmodule Teiserver.SpringAuthTest do
  use Central.ServerCase, async: false
  require Logger
  alias Teiserver.BitParse
  alias Teiserver.User
  alias Teiserver.Client
  alias Central.Account
  # alias Teiserver.Battle
  import Central.Helpers.NumberHelper, only: [int_parse: 1]

  import Teiserver.TeiserverTestLib,
    only: [
      auth_setup: 0,
      auth_setup: 1,
      _send: 2,
      _recv: 1,
      _recv_until: 1,
      new_user: 0,
      new_user: 2
    ]

  setup do
    %{socket: socket, user: user} = auth_setup()
    {:ok, socket: socket, user: user}
  end

  test "Test bad match", %{socket: socket} do
    # Previously a bad match on the data could cause a failure on the next
    # command as it corrupted state. This checks for that regression
    _send(socket, "^^\n")
    reply = _recv(socket)
    assert reply == :timeout

    _send(socket, "#4 PING\n")
    reply = _recv(socket)
    assert reply == "#4 PONG\n"
  end

  test "PING", %{socket: socket} do
    _send(socket, "#4 PING\n")
    reply = _recv(socket)
    assert reply == "#4 PONG\n"
  end

  test "GETUSERINFO", %{socket: socket, user: user} do
    _send(socket, "GETUSERINFO\n")
    reply = _recv(socket)
    assert reply =~ "SERVERMSG Registration date: "
    assert reply =~ "SERVERMSG Email address: #{user.email}"
    assert reply =~ "SERVERMSG Ingame time: "
  end

  test "MYSTATUS", %{socket: socket, user: user} do
    # Start by setting everything to 1, most of this
    # stuff we can't set. We should be rank 1, not a bot but are a mod
    _send(socket, "MYSTATUS 127\n")
    reply = _recv(socket)
    assert reply =~ "CLIENTSTATUS #{user.name} 3\n"
    reply_bits = BitParse.parse_bits("100", 7)

    # Lets make sure it's coming back the way we expect
    # [in_game, away, r1, r2, r3, mod, bot]
    [1, 1, 0, 0, 1, 0, 0] = reply_bits

    # Lets check we can correctly in-game
    new_status = Integer.undigits(Enum.reverse([0, 1, 0, 0, 0, 0, 0]), 2)
    _send(socket, "MYSTATUS #{new_status}\n")
    reply = _recv(socket)
    assert reply == "CLIENTSTATUS #{user.name} #{new_status}\n"

    # And now the away flag
    new_status = Integer.undigits(Enum.reverse([0, 0, 0, 0, 0, 0, 0]), 2)
    _send(socket, "MYSTATUS #{new_status}\n")
    reply = _recv(socket)
    assert reply == "CLIENTSTATUS #{user.name} #{new_status}\n"

    # And now we try for a bad mystatus command
    _send(socket, "MYSTATUS\n")
    reply = _recv(socket)
    assert reply == "SERVERMSG No incomming match for MYSTATUS with data ''\n"

    # Now change the password - incorrectly
    _send(socket, "CHANGEPASSWORD wrong_pass\tnew_pass\n")
    reply = _recv(socket)
    assert reply == "SERVERMSG Current password entered incorrectly\n"
    user = User.get_user_by_name(user.name)
    assert User.test_password("X03MO1qnZdYdgyfeuILPmQ==", user.password_hash)

    # Change it correctly
    _send(socket, "CHANGEPASSWORD X03MO1qnZdYdgyfeuILPmQ==\tnew_pass\n")
    :timer.sleep(1000)
    reply = _recv(socket)
    assert reply == "SERVERMSG Password changed, you will need to use it next time you login\n"
    user = User.get_user_by_name(user.name)
    assert User.test_password("new_pass", user.password_hash)

    # Test no match
    _send(socket, "CHANGEPASSWORD nomatchname\n")
    reply = _recv(socket)
    assert reply == "SERVERMSG No incomming match for CHANGEPASSWORD with data 'nomatchname'\n"
  end

  test "IGNORELIST, IGNORE, UNIGNORE, SAYPRIVATE", %{socket: socket1, user: user} do
    user2 = new_user()
    %{socket: socket2} = auth_setup(user2)
    reply = _recv(socket1)
    assert reply =~ "ADDUSER #{user2.name} ?? 0 #{user2.id} LuaLobby Chobby\n"
    assert reply =~ " LuaLobby Chobby\n"

    _send(socket1, "#111 IGNORELIST\n")
    reply = _recv(socket1)
    assert reply == "#111 IGNORELISTBEGIN
#111 IGNORELISTEND\n"

    # We expect no messages to be waiting for us
    reply = _recv(socket2)
    assert reply == :timeout

    # Send a message from 2 to 1
    _send(socket2, "SAYPRIVATE #{user.name} Hello there!\n")
    reply = _recv(socket1)
    assert reply == "SAIDPRIVATE #{user2.name} Hello there!\n"

    # Now lets ignore them
    _send(socket1, "IGNORE userName=#{user2.name}\n")
    reply = _recv(socket1)
    assert reply == "IGNORELISTBEGIN
IGNORELIST userName=#{user2.name}
IGNORELISTEND\n"

    # Send a message?
    _send(socket2, "SAYPRIVATE #{user.name} You still there?\n")
    reply = _recv(socket1)
    assert reply == :timeout

    # Now unignore them
    _send(socket1, "UNIGNORE userName=#{user2.name}\n")
    reply = _recv(socket1)
    assert reply == "IGNORELISTBEGIN
IGNORELISTEND\n"

    # Send a message?
    _send(socket2, "SAYPRIVATE #{user.name} What about now?\n")
    reply = _recv(socket1)
    assert reply == "SAIDPRIVATE #{user2.name} What about now?\n"
  end

  test "FRIENDLIST, ADDFRIEND, REMOVEFRIEIND, ACCEPTFRIENDREQUEST, DECLINEFRIENDREQUEST", %{
    socket: socket1,
    user: user
  } do
    user2 = new_user()
    %{socket: socket2} = auth_setup(user2)
    reply = _recv(socket1)
    assert reply =~ "ADDUSER #{user2.name} ?? 0 #{user2.id} LuaLobby Chobby\n"
    assert reply =~ " LuaLobby Chobby\n"

    _send(socket1, "#7 FRIENDLIST\n")
    reply = _recv(socket1)
    assert reply == "#7 FRIENDLISTBEGIN
#7 FRIENDLISTEND\n"

    _send(socket1, "#187 FRIENDREQUESTLIST\n")
    reply = _recv(socket1)
    assert reply == "#187 FRIENDREQUESTLISTBEGIN
#187 FRIENDREQUESTLISTEND\n"

    # Now we send the friend request
    _send(socket2, "FRIENDREQUEST userName=#{user.name}\n")
    reply = _recv(socket1)
    assert reply == "FRIENDREQUESTLISTBEGIN
FRIENDREQUESTLIST userName=#{user2.name}
FRIENDREQUESTLISTEND\n"

    # Accept the friend request
    _send(socket1, "ACCEPTFRIENDREQUEST userName=#{user2.name}\n")
    reply = _recv(socket1)
    assert reply == "FRIENDLISTBEGIN
FRIENDLIST userName=#{user2.name}
FRIENDLISTEND
FRIENDREQUESTLISTBEGIN
FRIENDREQUESTLISTEND\n"

    reply = _recv(socket2)
    assert reply == "FRIENDLISTBEGIN
FRIENDLIST userName=#{user.name}
FRIENDLISTEND\n"

    # Change of plan, remove them
    _send(socket1, "UNFRIEND userName=#{user2.name}\n")
    reply = _recv(socket1)
    assert reply == "FRIENDLISTBEGIN
FRIENDLISTEND\n"

    reply = _recv(socket2)
    assert reply == "FRIENDLISTBEGIN
FRIENDLISTEND\n"

    # Request a friend again so we can decline it
    _send(socket2, "FRIENDREQUEST userName=#{user.name}\n")
    reply = _recv(socket1)
    assert reply == "FRIENDREQUESTLISTBEGIN
FRIENDREQUESTLIST userName=#{user2.name}
FRIENDREQUESTLISTEND\n"

    # Decline the friend request
    _send(socket1, "DECLINEFRIENDREQUEST userName=#{user2.name}\n")
    reply = _recv(socket1)
    assert reply == "FRIENDREQUESTLISTBEGIN
FRIENDREQUESTLISTEND\n"

    reply = _recv(socket2)
    assert reply == :timeout
  end

  test "JOIN, LEAVE, SAY, CHANNELS, SAYEX", %{socket: socket, user: user} do
    _send(socket, "JOIN test_room\n")
    reply = _recv(socket)
    assert reply == "JOIN test_room
JOINED test_room #{user.name}
CHANNELTOPIC test_room #{user.name}
CLIENTS test_room #{user.name}\n"

    # Say something
    _send(socket, "SAY test_room Hello there\n")
    reply = _recv(socket)
    assert reply == "SAID test_room #{user.name} Hello there\n"

    # Sayex
    _send(socket, "SAYEX test_room A different message\n")
    reply = _recv(socket)
    assert reply == "SAIDEX test_room #{user.name} A different message\n"

    # Check for channel list
    _send(socket, "CHANNELS\n")
    reply = _recv(socket)
    assert reply == "CHANNELS
CHANNEL test_room 1
ENDOFCHANNELS\n"

    # Leave
    _send(socket, "LEAVE test_room\n")
    reply = _recv(socket)
    assert reply == "LEFT test_room #{user.name}\n"

    # Check for channel list
    _send(socket, "CHANNELS\n")
    reply = _recv(socket)
    assert reply == "CHANNELS
CHANNEL test_room 0
ENDOFCHANNELS\n"

    # Say something
    _send(socket, "SAY test_room Second test\n")
    reply = _recv(socket)
    assert reply == :timeout
  end

  test "JOINBATTLE, SAYBATTLE, MYBATTLESTATUS, LEAVEBATTLE", %{socket: socket1, user: user1} do
    hash = "-1540855590"

    _send(
      socket1,
      "OPENBATTLE 0 0 * 52200 16 #{hash} 0 1565299817 spring\t104.0.1-1784-gf6173b4 BAR\tauth_joinbattle_test\tEU - 00\tBeyond All Reason test-15658-85bf66d\n"
    )

    reply = _recv_until(socket1)

    assert reply =~ "BATTLEOPENED "
    assert reply =~ "OPENBATTLE "

    [_, battle_id] = Regex.run(~r/OPENBATTLE ([0-9]+)\n/, reply)
    battle_id = int_parse(battle_id)

    user2 = new_user()
    %{socket: socket2} = auth_setup(user2)
    _ = _recv(socket1)

    _send(socket2, "JOINBATTLE #{battle_id} empty sPassword\n")
    _ = _recv(socket2)

    # User1 (host) should now get a message
    reply = _recv(socket1)
    assert reply == "JOINBATTLEREQUEST #{user2.name} 127.0.0.1\n"

    # User1, reject it!
    _send(socket1, "JOINBATTLEDENY #{user2.name} Because I said so\n")
    reply = _recv(socket2)
    assert reply == "JOINBATTLEFAILED Because I said so\n"

    # Rejoin, this time accept, also this time use the SpringLobby method of an actually empty password
    _send(socket2, "JOINBATTLE #{battle_id}  sPassword\n")
    _send(socket1, "JOINBATTLEACCEPT #{user2.name}\n")
    _ = _recv(socket1)

    reply =
      _recv_until(socket2)
      |> String.split("\n")

    # The remainder of this string is just the script tags, we'll assume it's correct for now
    # Now stuff happens right?
    [
      joinbattle,
      joinedbattle,
      tags,
      host_bstatus,
      bstatus,
      request,
      ""
    ] = reply

    assert joinbattle == "JOINBATTLE #{battle_id} #{hash}"
    assert joinedbattle == "JOINEDBATTLE #{battle_id} #{user2.name} sPassword"
    assert tags == "SETSCRIPTTAGS "
    assert bstatus == "CLIENTBATTLESTATUS #{user2.name} 0 0"
    assert host_bstatus == "CLIENTBATTLESTATUS #{user1.name} 0 0"
    assert request == "REQUESTBATTLESTATUS"

    _send(socket2, "SAYBATTLE Hello there!\n")
    reply = _recv(socket2)
    assert reply == "SAIDBATTLE #{user2.name} Hello there!\n"

    _send(socket2, "MYBATTLESTATUS 12 0\n")
    reply = _recv(socket2)
    assert reply == "CLIENTBATTLESTATUS #{user2.name} 12 0\n"

    # Add a bot
    _send(socket2, "ADDBOT STAI(1) 4195458 0 STAI\n")
    reply = _recv(socket2)
    [_, botid] = Regex.run(~r/ADDBOT (\d+) STAI\(1\) #{user2.name} 4195458 0 STAI/, reply)
    botid = int_parse(botid)
    assert reply == "ADDBOT #{botid} STAI(1) #{user2.name} 4195458 0 STAI\n"

    # # Promote?
    # _send(socket2, "PROMOTE\n")
    # _ = _recv(socket2)

    # Time to leave
    _send(socket2, "LEAVEBATTLE\n")
    reply = _recv(socket2)
    assert reply == "LEFTBATTLE #{battle_id} #{user2.name}\n"

    # These commands shouldn't work, they also shouldn't error
    _send(socket2, "SAYBATTLE I'm not here anymore!\n")
    reply = _recv(socket2)
    assert reply == :timeout

    _send(socket2, "MYBATTLESTATUS 12 0\n")
    reply = _recv(socket2)
    assert reply == :timeout

    _send(socket2, "LEAVEBATTLE\n")
    reply = _recv(socket2)
    assert reply == :timeout
  end

  test "ring", %{socket: socket1, user: user1} do
    user2 = new_user()
    %{socket: socket2} = auth_setup(user2)
    reply = _recv(socket1)
    assert reply =~ "ADDUSER #{user2.name} ?? 0 #{user2.id} LuaLobby Chobby\n"

    _send(socket2, "RING #{user1.name}\n")
    _ = _recv(socket2)

    reply = _recv(socket1)
    assert reply == "RING #{user2.name}\n"
  end

  test "LISTCOMPFLAGS", %{socket: socket} do
    _send(socket, "LISTCOMPFLAGS\n")
    reply = _recv(socket)
    assert reply =~ "COMPFLAGS "
    assert reply =~ "matchmaking"
    assert reply =~ "teiserver"
    assert reply =~ "token-auth"
  end

  test "c.battles.list_ids", %{socket: socket} do
    _send(socket, "c.battles.list_ids\n")
    reply = _recv(socket)
    assert reply =~ "s.battles.id_list "
  end

  test "RENAMEACCOUNT", %{socket: socket, user: user} do
    old_name = user.name
    new_name = "rename_test_user"
    userid = user.id
    %{socket: watcher, user: watcher_user} = auth_setup()
    _recv(socket)

    # Check our starting situation
    assert User.get_user_by_name(new_name) == nil
    assert User.get_user_by_name(old_name) != nil
    assert User.get_user_by_id(userid) != nil
    assert Client.get_client_by_id(userid) != nil

    # Rename with an invalid name
    _send(socket, "RENAMEACCOUNT Y--Y\n")
    reply = _recv(socket)
    assert reply == "SERVERMSG Invalid characters in name (only a-z, A-Z, 0-9, [, ] allowed)\n"

    # Rename with existng name
    _send(socket, "RENAMEACCOUNT #{watcher_user.name}\n")
    reply = _recv(socket)
    assert reply == "SERVERMSG Username already taken\n"

    # Perform rename
    _send(socket, "RENAMEACCOUNT rename_test_user\n")
    reply = _recv(socket)
    # assert reply == "SERVERMSG Username change in progress, please log back in in 5 seconds\n"
    assert reply == :timeout

    # Check they got logged out
    wreply = _recv(watcher)
    assert wreply == "REMOVEUSER #{user.name}\n"

    # Give it a chance to perform some of the actions
    :timer.sleep(250)

    # User is removed and uncached, it should be nil
    assert User.get_user_by_name(new_name) == nil
    assert User.get_user_by_name(user.name) == nil
    assert User.get_user_by_id(userid) == nil
    assert Client.get_client_by_id(userid) == nil

    # Lets be REAL sure
    client_ids = Client.list_client_ids()
    assert user.id not in client_ids

    # Check they got logged out
    wreply = _recv(watcher)
    assert wreply == :timeout

    # No need to send an exit, it's already sorted out!
    # we should try to login though, it should be rejected as rename in progress
    %{socket: socket} = Teiserver.TeiserverTestLib.raw_setup()
    _ = _recv(socket)
    _send(
      socket,
      "LOGIN #{new_name} X03MO1qnZdYdgyfeuILPmQ== 0 * LuaLobby Chobby\t1993717506\t0d04a635e200f308\tb sp\n"
    )

    reply = _recv_until(socket)
    [accepted | _remainder] = String.split(reply, "\n")
    assert accepted == "DENIED No user found for 'rename_test_user'"

    # But the database should say the user exists
    db_user = Account.get_user!(userid)
    assert db_user.name == new_name

    # Didn't get re-added just yet
    wreply = _recv(watcher)
    assert wreply == :timeout

    # Lets try again, just incase!
    :timer.sleep(1500)

    _send(
      socket,
      "LOGIN #{new_name} X03MO1qnZdYdgyfeuILPmQ== 0 * LuaLobby Chobby\t1993717506\t0d04a635e200f308\tb sp\n"
    )

    reply = _recv_until(socket)
    [accepted | _remainder] = String.split(reply, "\n")
    assert accepted == "DENIED No user found for 'rename_test_user'"

    :timer.sleep(4000)

    # Now they can log in again
    _send(
      socket,
      "LOGIN #{new_name} X03MO1qnZdYdgyfeuILPmQ== 0 * LuaLobby Chobby\t1993717506\t0d04a635e200f308\tb sp\n"
    )

    reply = _recv_until(socket)
    [accepted | _remainder] = String.split(reply, "\n")
    assert accepted == "ACCEPTED rename_test_user"

    # Check they logged back in and got re-added with the correct name
    wreply = _recv(watcher)
    assert wreply == "ADDUSER rename_test_user ?? 0 #{user.id} LuaLobby Chobby\nCLIENTSTATUS rename_test_user 0\n"

    # Next up, what if they update their status?
    _send(socket, "MYSTATUS 127\n")
    wreply = _recv(watcher)
    assert wreply == "CLIENTSTATUS #{new_name} 3\n"

    _send(socket, "EXIT\n")
  end

  test "CHANGEEMAIL", %{socket: socket, user: user} do
    # Make the request
    _send(socket, "CHANGEEMAILREQUEST new_email@email.com\n")
    reply = _recv(socket)
    assert reply == "CHANGEEMAILREQUESTACCEPTED\n"
    new_user = User.get_user_by_id(user.id)
    [code, new_email] = new_user.email_change_code
    assert new_email == "new_email@email.com"

    # Submit a bad code
    _send(socket, "CHANGEEMAIL new_email@email.com bad_code\n")
    reply = _recv(socket)
    assert reply == "CHANGEEMAILDENIED bad code\n"

    # Submit a bad email
    _send(socket, "CHANGEEMAIL bad_email #{code}\n")
    reply = _recv(socket)
    assert reply == "CHANGEEMAILDENIED bad email\n"

    # Now do it correctly
    _send(socket, "CHANGEEMAIL new_email@email.com #{code}\n")
    reply = _recv(socket)
    assert reply == "CHANGEEMAILACCEPTED\n"
    new_user = User.get_user_by_id(user.id)
    assert new_user.email == "new_email@email.com"
    assert new_user.email_change_code == [nil, nil]
  end

  test "CREATEBOTACCOUNT - no mod", %{socket: socket, user: user} do
    _send(socket, "CREATEBOTACCOUNT test_bot_account_no_mod #{user.name}\n")
    reply = _recv(socket)
    assert reply == "SERVERMSG You do not have permission to execute that command\n"

    # Give mod access, recache the user
    User.update_user(%{user | moderator: true})
    :timer.sleep(100)

    _send(socket, "CREATEBOTACCOUNT test_bot_account #{user.name}\n")
    reply = _recv(socket)

    assert reply ==
             "SERVERMSG A new bot account test_bot_account has been created, with the same password as #{
               user.name
             }\n"

    # Test no match
    _send(socket, "CREATEBOTACCOUNT nomatchname\n")
    reply = _recv(socket)
    assert reply == "SERVERMSG No incomming match for CREATEBOTACCOUNT with data 'nomatchname'\n"
  end

  test "Ranks" do
    user = new_user("new_test_user_rank_test", %{"ingame_minutes" => 60 * 200, "rank" => 5})
    %{socket: socket} = auth_setup(user)

    # [in_game, away, r3, r2, r1, mod, bot]
    new_status = Integer.undigits(Enum.reverse([0, 1, 0, 0, 1, 0, 0]), 2)
    _send(socket, "MYSTATUS #{new_status}\n")
    reply = _recv(socket)
    assert reply == "CLIENTSTATUS #{user.name} #{new_status}\n"
  end
end
