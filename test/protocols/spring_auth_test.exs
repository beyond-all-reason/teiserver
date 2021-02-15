defmodule Teiserver.SpringAuthTest do
  use ExUnit.Case
  require Logger
  alias Teiserver.BitParse
  alias Teiserver.User
  import Teiserver.TestLib, only: [auth_setup: 0, auth_setup: 1, _send: 2, _recv: 1]

  setup do
    %{socket: socket} = auth_setup()
    {:ok, socket: socket}
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

  test "GETUSERINFO", %{socket: socket} do
    _send(socket, "GETUSERINFO\n")
    reply = _recv(socket)
    assert reply == "SERVERMSG Registration date: yesterday
SERVERMSG Email address: TestUser@TestUser.com
SERVERMSG Ingame time: xyz hours\n"
  end

  test "MYSTATUS", %{socket: socket} do
    # Start by setting everything to 1, most of this
    # stuff we can't set. We should be rank 1, not a bot but are a mod
    _send(socket, "MYSTATUS 127\n")
    "CLIENTSTATUS TestUser\t" <> reply = _recv(socket)
    assert reply == "102\n"
    reply_bits = BitParse.parse_bits(String.trim(reply), 7)

    # Lets make sure it's coming back the way we expect
    # [in_game, away, r1, r2, r3, mod, bot]
    [1, 1, 0, 0, 1, 1, 0] = reply_bits

    # Lets check we can correctly in-game
    new_status = Integer.undigits([0, 1, 0, 0, 1, 1, 0], 2)
    _send(socket, "MYSTATUS #{new_status}\n")
    reply = _recv(socket)
    assert reply == "CLIENTSTATUS TestUser\t#{new_status}\n"

    # And now the away flag
    new_status = Integer.undigits([0, 0, 0, 0, 1, 1, 0], 2)
    _send(socket, "MYSTATUS #{new_status}\n")
    reply = _recv(socket)
    assert reply == "CLIENTSTATUS TestUser\t#{new_status}\n"
    
    # And now we try for a bad mystatus command
    _send(socket, "MYSTATUS\n")
    reply = _recv(socket)
    assert reply == :timeout
    
    # Now change the password - incorrectly
    _send(socket, "CHANGEPASSWORD wrong_pass\tnew_pass\n")
    reply = _recv(socket)
    assert reply == "SERVERMSG Current password entered incorrectly\n"
    user = User.get_user_by_name("TestUser")
    assert user.password_hash == "X03MO1qnZdYdgyfeuILPmQ=="

    # Change it correctly
    _send(socket, "CHANGEPASSWORD password\tnew_pass\n")
    reply = _recv(socket)
    assert reply == "SERVERMSG Password changed, you will need to use it next time you login\n"
    user = User.get_user_by_name("TestUser")
    assert user.password_hash != "X03MO1qnZdYdgyfeuILPmQ=="
  end

  test "IGNORELIST, IGNORE, UNIGNORE, SAYPRIVATE", %{socket: socket1} do
    %{socket: socket2} = auth_setup("TestUser2")
    reply = _recv(socket1)
    assert reply == "ADDUSER TestUser2 GB 4\tLuaLobby Chobby\n"

    _send(socket1, "#111 IGNORELIST\n")
    reply = _recv(socket1)
    assert reply == "#111 IGNORELISTBEGIN
#111 IGNORELIST userName=Ignored1
#111 IGNORELIST userName=Ignored2
#111 IGNORELISTEND\n"

    # We expect no messages to be waiting for us
    reply = _recv(socket2)
    assert reply == :timeout

    # Send a message from 2 to 1
    _send(socket2, "SAYPRIVATE TestUser Hello there!\n")
    reply = _recv(socket1)
    assert reply == "SAIDPRIVATE TestUser2 Hello there!\n"

    # Now lets ignore them
    _send(socket1, "IGNORE userName=TestUser2\n")
    reply = _recv(socket1)
    assert reply == "IGNORELISTBEGIN
IGNORELIST userName=Ignored1
IGNORELIST userName=Ignored2
IGNORELIST userName=TestUser2
IGNORELISTEND\n"

    # Send a message?
    _send(socket2, "SAYPRIVATE TestUser You still there?\n")
    reply = _recv(socket1)
    assert reply == :timeout
    
    # Now unignore them
    _send(socket1, "UNIGNORE userName=TestUser2\n")
    reply = _recv(socket1)
    assert reply == "IGNORELISTBEGIN
IGNORELIST userName=Ignored1
IGNORELIST userName=Ignored2
IGNORELISTEND\n"

    # Send a message?
    _send(socket2, "SAYPRIVATE TestUser What about now?\n")
    reply = _recv(socket1)
    assert reply == "SAIDPRIVATE TestUser2 What about now?\n"
  end

  test "FRIENDLIST, ADDFRIEND, REMOVEFRIEIND, ACCEPTFRIENDREQUEST, DECLINEFRIENDREQUEST", %{socket: socket1} do
    %{socket: socket2} = auth_setup("TestUser2")
    reply = _recv(socket1)
    assert reply == "ADDUSER TestUser2 GB 4\tLuaLobby Chobby\n"

    _send(socket1, "#7 FRIENDLIST\n")
    reply = _recv(socket1)
    assert reply == "#7 FRIENDLISTBEGIN
#7 FRIENDLIST userName=Friend1
#7 FRIENDLIST userName=Friend2
#7 FRIENDLISTEND\n"

    _send(socket1, "#187 FRIENDREQUESTLIST\n")
    reply = _recv(socket1)
    assert reply == "#187 FRIENDREQUESTLISTBEGIN
#187 FRIENDREQUESTLIST userName=FriendRequest1
#187 FRIENDREQUESTLISTEND\n"

    # Now we send the friend request
    _send(socket2, "FRIENDREQUEST userName=TestUser\n")
    reply = _recv(socket1)
    assert reply == "FRIENDREQUESTLISTBEGIN
FRIENDREQUESTLIST userName=FriendRequest1
FRIENDREQUESTLIST userName=TestUser2
FRIENDREQUESTLISTEND\n"

    # Accept the friend request
    _send(socket1, "ACCEPTFRIENDREQUEST userName=TestUser2\n")
    reply = _recv(socket1)
    assert reply == "FRIENDLISTBEGIN
FRIENDLIST userName=Friend1
FRIENDLIST userName=Friend2
FRIENDLIST userName=TestUser2
FRIENDLISTEND
FRIENDREQUESTLISTBEGIN
FRIENDREQUESTLIST userName=FriendRequest1
FRIENDREQUESTLISTEND\n"

    reply = _recv(socket2)
    assert reply == "FRIENDLISTBEGIN
FRIENDLIST userName=TestUser
FRIENDLISTEND\n"

    # Change of plan, remove them
    _send(socket1, "UNFRIEND userName=TestUser2\n")
    reply = _recv(socket1)
    assert reply == "FRIENDLISTBEGIN
FRIENDLIST userName=Friend1
FRIENDLIST userName=Friend2
FRIENDLISTEND\n"

    reply = _recv(socket2)
    assert reply == "FRIENDLISTBEGIN
FRIENDLISTEND\n"

    # Request a friend again so we can decline it
    _send(socket2, "FRIENDREQUEST userName=TestUser\n")
    reply = _recv(socket1)
    assert reply == "FRIENDREQUESTLISTBEGIN
FRIENDREQUESTLIST userName=FriendRequest1
FRIENDREQUESTLIST userName=TestUser2
FRIENDREQUESTLISTEND\n"

    # Decline the friend request
    _send(socket1, "DECLINEFRIENDREQUEST userName=TestUser2\n")
    reply = _recv(socket1)
    assert reply == "FRIENDREQUESTLISTBEGIN
FRIENDREQUESTLIST userName=FriendRequest1
FRIENDREQUESTLISTEND\n"

    reply = _recv(socket2)
    assert reply == :timeout
  end

  test "JOIN, LEAVE, SAY, CHANNELS", %{socket: socket} do
    _send(socket, "JOIN test_room\n")
    reply = _recv(socket)
    assert reply == "JOIN test_room
JOINED test_room TestUser
CHANNELTOPIC test_room no author
CLIENTS test_room TestUser\n"

    # Say something
    _send(socket, "SAY test_room Hello there\n")
    reply = _recv(socket)
    assert reply == "SAID test_room TestUser Hello there\n"

    # Check for channel list
    _send(socket, "CHANNELS\n")
    reply = _recv(socket)
    assert reply == "CHANNELS
CHANNEL main 1
CHANNEL test_room 1
ENDOFCHANNELS\n"

    # Leave
    _send(socket, "LEAVE test_room\n")
    reply = _recv(socket)
    assert reply == "LEFT test_room TestUser\n"

    # Check for channel list
    _send(socket, "CHANNELS\n")
    reply = _recv(socket)
    assert reply == "CHANNELS
CHANNEL main 1
CHANNEL test_room 0
ENDOFCHANNELS\n"

    # Say something
    _send(socket, "SAY test_room Second test\n")
    reply = _recv(socket)
    assert reply == :timeout
  end

  test "JOINBATTLE, SAYBATTLE, MYBATTLESTATUS, LEAVEBATTLE", %{socket: socket} do
    _send(socket, "JOINBATTLE 1 empty 1683043765\n")
    # The remainder of this string is just the script tags, we'll assume it's correct for now
    part1 = _recv(socket)
    part2 = _recv(socket)
    :timeout = _recv(socket)
    
    reply = (part1 <> part2)
    |> String.split("\n")
    
    [join, _tags, client1, client2, rect1, rect2, battle_status, saidbattle, joinedbattle, clientstatus, ""] = reply
    
    assert join == "JOINBATTLE 1 1683043765"
    assert client1 == "CLIENTBATTLESTATUS [teh]cluster1[03] 4194306 16777215"
    assert client2 == "CLIENTBATTLESTATUS TestUser 0 0"
    assert rect1 == "ADDSTARTRECT 0 0 126 74 200"
    assert rect2 == "ADDSTARTRECT 1 126 0 200 74"
    assert battle_status == "REQUESTBATTLESTATUS"
    assert saidbattle == "SAIDBATTLEEX [teh]cluster1[03] Hi TestUser! Current battle type is faked_team."
    assert joinedbattle == "JOINEDBATTLE TestUser 1"
    assert clientstatus == "CLIENTSTATUS TestUser\t6"

    _send(socket, "SAYBATTLE Hello there!\n")
    reply = _recv(socket)
    assert reply == "SAIDBATTLE TestUser Hello there!\n"

    _send(socket, "MYBATTLESTATUS 12 0\n")
    reply = _recv(socket)
    assert reply == "CLIENTBATTLESTATUS TestUser 0 0\n"

    # Time to leave
    _send(socket, "LEAVEBATTLE\n")
    reply = _recv(socket)
    assert reply == "LEFTBATTLE 1 TestUser
CLIENTBATTLESTATUS TestUser 0 0\n"

    # These commands shouldn't work, they also shouldn't error
    _send(socket, "SAYBATTLE I'm not here anymore!\n")
    reply = _recv(socket)
    assert reply == :timeout

    _send(socket, "MYBATTLESTATUS 12 0\n")
    reply = _recv(socket)
    assert reply == :timeout

    _send(socket, "LEAVEBATTLE\n")
    reply = _recv(socket)
    assert reply == :timeout
  end

  test "ring", %{socket: socket1} do
    %{socket: socket2} = auth_setup("TestUser2")
    reply = _recv(socket1)
    assert reply == "ADDUSER TestUser2 GB 4\tLuaLobby Chobby\n"

    _send(socket2, "RING TestUser\n")
    reply = _recv(socket2)
    assert reply == :timeout

    reply = _recv(socket1)
    assert reply == "RING TestUser2\n"
  end
end
