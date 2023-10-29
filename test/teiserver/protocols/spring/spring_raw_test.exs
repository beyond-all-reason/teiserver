defmodule Teiserver.SpringRawTest do
  use Teiserver.ServerCase, async: false

  import Teiserver.TeiserverTestLib,
    only: [raw_setup: 0, _send_raw: 2, _recv_raw: 1, _recv_until: 1, new_user: 0]

  alias Teiserver.Account.UserCacheLib
  alias Central.Account

  setup do
    %{socket: socket} = raw_setup()
    {:ok, socket: socket}
  end

  test "ping", %{socket: socket} do
    _ = _recv_raw(socket)
    _send_raw(socket, "#4 PING\n")
    reply = _recv_raw(socket)
    assert reply =~ "#4 PONG\n"
  end

  test "REGISTER", %{socket: socket} do
    _ = _recv_raw(socket)
    existing = new_user()
    name = "TestUser_raw_reg"

    # Failure first - bad name
    _send_raw(socket, "REGISTER bad-name password raw_register_email@email.com\n")
    reply = _recv_raw(socket)

    assert reply =~
             "REGISTRATIONDENIED Invalid characters in name (only a-z, A-Z, 0-9, [, ] and _ allowed)\n"

    # Failure first - existing name
    _send_raw(socket, "REGISTER #{existing.name} password raw_register_email@email.com\n")
    reply = _recv_raw(socket)
    assert reply =~ "REGISTRATIONDENIED Username already taken\n"

    # Failure first - existing email
    _send_raw(socket, "REGISTER new_name_here password #{existing.email}\n")
    reply = _recv_raw(socket)
    assert reply =~ "REGISTRATIONDENIED Email already attached to a user (#{existing.email})\n"

    # Too long
    _send_raw(socket, "REGISTER longnamelongnamelongname password raw_register_email@email.com\n")
    reply = _recv_raw(socket)
    assert reply =~ "REGISTRATIONDENIED Max length 20 characters\n"

    # Success second
    _send_raw(socket, "REGISTER #{name} password raw_register_email@email.com\n")
    reply = _recv_raw(socket)
    assert reply =~ "REGISTRATIONACCEPTED\n"
    user = UserCacheLib.get_user_by_name(name)
    assert user != nil

    # Now check the DB!
    db_users = Account.list_users(search: [name: name])
    assert Enum.count(db_users) == 1
  end

  test "LOGIN", %{socket: socket} do
    username = "test_user_raw"

    # We expect to be greeted by a welcome message
    reply = _recv_raw(socket)
    assert reply == "TASSERVER 0.38-33-ga5f3b28 * 8201 0\n"

    _send_raw(socket, "REGISTER #{username} X03MO1qnZdYdgyfeuILPmQ== #{username}@email.e\n")
    _ = _recv_raw(socket)
    user = UserCacheLib.get_user_by_name(username)
    assert user != nil
    UserCacheLib.update_user(%{user | verified: true})

    # First try to login with a bad-case username
    _send_raw(
      socket,
      "LOGIN #{String.upcase(username)} X03MO1qnZdYdgyfeuILPmQ== 0 * LuaLobby Chobby\t1993717506 0d04a635e200f308\tb sp\n"
    )

    reply = _recv_raw(socket)
    assert reply == "DENIED Username is case sensitive, try 'test_user_raw'\n"

    _send_raw(
      socket,
      "LOGIN #{username} X03MO1qnZdYdgyfeuILPmQ== 0 * LuaLobby Chobby\t1993717506 0d04a635e200f308\tb sp\n"
    )

    reply = _recv_until(socket)
    [accepted | remainder] = String.split(reply, "\n")
    user = UserCacheLib.get_user_by_name(username)

    assert accepted == "ACCEPTED #{username}",
      message:
        "Bad password, gave X03MO1qnZdYdgyfeuILPmQ== but needed #{user.password_hash}. Accepted message is #{accepted}"

    commands =
      remainder
      |> Enum.map(fn line -> String.split(line, " ") |> hd end)
      |> Enum.uniq()

    # Due to things running concurrently it's possible either of these will be the case
    assert commands == [
             "MOTD",
             "ADDUSER",
             "CLIENTSTATUS",
             "BATTLEOPENED",
             "UPDATEBATTLEINFO",
             "JOINEDBATTLE",
             "LOGININFOEND",
             ""
           ] or
             commands == [
               "MOTD",
               "ADDUSER",
               "CLIENTSTATUS",
               "LOGININFOEND",
               ""
             ],
           message: "Got: #{inspect(commands)}"

    _send_raw(socket, "EXIT\n")
    _ = _recv_raw(socket)

    # Is it actually killed?
    {:error, :closed} = :gen_tcp.recv(socket, 0, 1000)
  end

  # Currently not active
  # test "CONFIRMAGREEMENT", %{socket: socket} do
  #   user = new_user()
  #   Teiserver.Account.update_user_stat(user.id, %{"verification_code" => "123456"})
  #   user = UserCacheLib.update_user(%{user | verified: false, roles: []}, persist: true)

  #   query = "UPDATE account_users SET inserted_at = '2020-01-01 01:01:01' WHERE id = #{user.id}"
  #   Ecto.Adapters.SQL.query(Repo, query, [])
  #   Teiserver.Account.UserCacheLib.recache_user(user.id)
  #   _ = _recv_raw(socket)

  #   # If we try to login as them we should get a specific failure
  #   _send_raw(
  #     socket,
  #     "LOGIN #{user.name} X03MO1qnZdYdgyfeuILPmQ== 0 * LuaLobby Chobby\t1993717506 0d04a635e200f308\tb sp\n"
  #   )

  #   reply = _recv_raw(socket)
  #   assert reply =~ "AGREEMENT User agreement goes here.\nAGREEMENT \nAGREEMENTEND\n"

  #   # Verify user - bad code
  #   _send_raw(socket, "CONFIRMAGREEMENT 000000000\n")
  #   reply = _recv_raw(socket)
  #   assert reply =~ "DENIED Incorrect code\n"

  #   # Verify user - good code
  #   _send_raw(socket, "CONFIRMAGREEMENT 123456\n")
  #   reply = _recv_raw(socket)
  #   assert reply =~ "ACCEPTED #{user.name}\n"
  #   assert reply =~ "MOTD Message of the day\n"
  #   assert reply =~ "LOGININFOEND\n"
  # end

  test "RESETPASSWORDREQUEST", %{socket: socket} do
    _ = _recv_raw(socket)

    # Send the wrong request
    _send_raw(
      socket,
      "RESETPASSWORDREQUEST\n"
    )

    reply = _recv_raw(socket)
    assert reply == "OK cmd=https://localhost/password_reset\n"
  end

  # TODO - Implement STLS and find a way to test it
  # test "STLS" do
  #   flunk("Not tested")
  # end

  test "login flood protection", %{socket: socket} do
    user = new_user()

    # Update the login count
    Central.cache_put(:teiserver_login_count, user.id, 9999)

    # Welcome message
    _recv_raw(socket)

    _send_raw(
      socket,
      "LOGIN #{user.name} X03MO1qnZdYdgyfeuILPmQ== 0 * LuaLobby Chobby\t1993717506 0d04a635e200f308\tb sp\n"
    )

    reply = _recv_until(socket)
    assert reply == "DENIED Flood protection - Please wait 20 seconds and try again\n"
  end
end
