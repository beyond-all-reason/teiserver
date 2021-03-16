defmodule Teiserver.SpringRawTest do
  use Central.ServerCase, async: false

  import Teiserver.TestLib,
    only: [raw_setup: 0, _send: 2, _recv: 1, _recv_until: 1, new_user: 0]

  alias Teiserver.User
  alias Central.Account

  setup do
    %{socket: socket} = raw_setup()
    {:ok, socket: socket}
  end

  test "ping", %{socket: socket} do
    _ = _recv(socket)
    _send(socket, "#4 PING\n")
    reply = _recv(socket)
    assert reply =~ "#4 PONG\n"
  end

  test "REGISTER", %{socket: socket} do
    _ = _recv(socket)
    existing = new_user()
    name = "TestUser_raw_register"

    # Failure first
    _send(socket, "REGISTER #{existing.name} password raw_register_email@email.com\n")
    reply = _recv(socket)
    assert reply =~ "REGISTRATIONDENIED User already exists\n"

    # Success second
    _send(socket, "REGISTER #{name} password raw_register_email@email.com\n")
    reply = _recv(socket)
    assert reply =~ "REGISTRATIONACCEPTED\n"
    user = User.get_user_by_name(name)
    assert user != nil

    # Now check the DB!
    [db_user] = Account.list_users(search: [name: name], joins: [:groups])
    assert Enum.count(db_user.groups) == 1
  end

  test "LOGIN", %{socket: socket} do
    username = "raw_new_user_test"

    # We expect to be greeted by a welcome message
    reply = _recv(socket)
    assert reply == "TASSERVER 0.38-33-ga5f3b28 * 8201 0\n"

    _send(socket, "REGISTER #{username} X03MO1qnZdYdgyfeuILPmQ== #{username}@email\n")
    _ = _recv(socket)
    user = User.get_user_by_name(username)
    assert user != nil
    User.update_user(%{user | verified: true})

    _send(
      socket,
      "LOGIN #{username} X03MO1qnZdYdgyfeuILPmQ== 0 * LuaLobby Chobby\t1993717506\t0d04a635e200f308\tb sp\n"
    )
    reply = _recv_until(socket)
    [accepted | remainder] = String.split(reply, "\n")
    user = User.get_user_by_name(username)

    assert accepted == "ACCEPTED #{username}",
      message: "Bad password, gave X03MO1qnZdYdgyfeuILPmQ== but needed #{user.password_hash}. Accepted message is #{accepted}"

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
             ]

    _send(socket, "EXIT\n")
    _ = _recv(socket)

    # Is it actually killed?
    {:error, :enotconn} = :gen_tcp.recv(socket, 0, 1000)
  end

  # test "CONFIRMAGREEMENT", %{socket: socket} do
  #   user = new_user()
  #   user = User.update_user(%{user | verification_code: 123456, verified: false})
  #   _ = _recv(socket)

  #   # If we try to login as them we should get a specific failure
  #   _send(socket, "LOGIN #{user.name} X03MO1qnZdYdgyfeuILPmQ== 0 * LuaLobby Chobby\t1993717506\t0d04a635e200f308\tb sp\n")
  #   reply = _recv(socket)
  #   assert reply =~ "DENIED Account not verified\n"
  # end

  test "RESETPASSWORDREQUEST", %{socket: socket} do
    user = new_user()
    _ = _recv(socket)

    # Send the wrong request
    _send(
      socket,
      "RESETPASSWORDREQUEST not_an_email\n"
    )

    reply = _recv(socket)
    assert reply =~ "RESETPASSWORDREQUESTDENIED user error\n"

    # Send the correct request
    _send(
      socket,
      "RESETPASSWORDREQUEST #{user.email}\n"
    )

    assert user.password_reset_code == nil
    user2 = User.get_user_by_id(user.id)
    assert user2.password_reset_code != nil
    reply = _recv(socket)
    assert reply =~ "RESETPASSWORDREQUESTACCEPTED\n"
    user = user2

    # Now verify badly
    _send(
      socket,
      "RESETPASSWORD #{user.email} the_wrong_code\n"
    )

    reply = _recv(socket)
    assert reply =~ "RESETPASSWORDDENIED wrong_code\n"
    user2 = User.get_user_by_id(user.id)
    assert user2.password_hash == user.password_hash

    # Now verify correctly
    _send(
      socket,
      "RESETPASSWORD #{user.email} #{user.password_reset_code}\n"
    )

    reply = _recv(socket)
    assert reply == "RESETPASSWORDACCEPTED\n"
    user2 = User.get_user_by_id(user.id)
    assert user2.password_hash != user.password_hash
    assert user2.password_reset_code == nil
  end

  # TODO - Implement STLS and find a way to test it
  # test "STLS" do
  #   flunk("Not tested")
  # end
end
