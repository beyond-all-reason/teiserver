defmodule Teiserver.SpringAuthTest do
  use ExUnit.Case
  alias Teiserver.BitParse
  import Teiserver.TestLib, only: [auth_setup: 0, _send: 2, _recv: 1]

  setup do
    %{socket: socket} = auth_setup()
    {:ok, socket: socket}
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

  test "FRIENDLIST", %{socket: socket} do
    _send(socket, "#7 FRIENDLIST\n")
    reply = _recv(socket)
    assert reply == "#7 FRIENDLISTBEGIN
#7 FRIENDLIST userName=Friend1
#7 FRIENDLIST userName=Friend2
#7 FRIENDLISTEND\n"
  end

  test "FRIENDREQUESTLIST", %{socket: socket} do
    _send(socket, "#7 FRIENDREQUESTLIST\n")
    reply = _recv(socket)
    assert reply == "#7 FRIENDREQUESTLISTBEGIN
#7 FRIENDREQUESTLIST userName=FriendRequest1
#7 FRIENDREQUESTLISTEND\n"
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
  end
end