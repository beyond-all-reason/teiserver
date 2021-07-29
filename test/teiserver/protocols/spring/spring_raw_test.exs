defmodule Teiserver.SpringRawTest do
  use Central.ServerCase, async: false

  import Teiserver.TeiserverTestLib,
    only: [raw_setup: 0, _send_raw: 2, _recv_raw: 1, _recv_until: 1, new_user: 0]

  alias Teiserver.User
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
    name = "TestUser_raw_register"

    # Failure first - bad name
    _send_raw(socket, "REGISTER bad-name password raw_register_email@email.com\n")
    reply = _recv_raw(socket)
    assert reply =~ "REGISTRATIONDENIED Invalid characters in name (only a-z, A-Z, 0-9, [, ] allowed)\n"

    # Failure first - existing name
    _send_raw(socket, "REGISTER #{existing.name} password raw_register_email@email.com\n")
    reply = _recv_raw(socket)
    assert reply =~ "REGISTRATIONDENIED Username already taken\n"

    # Failure first - existing email
    _send_raw(socket, "REGISTER new_name_here password #{existing.email}\n")
    reply = _recv_raw(socket)
    assert reply =~ "REGISTRATIONDENIED User already exists\n"

    # Success second
    _send_raw(socket, "REGISTER #{name} password raw_register_email@email.com\n")
    reply = _recv_raw(socket)
    assert reply =~ "REGISTRATIONACCEPTED\n"
    user = User.get_user_by_name(name)
    assert user != nil

    # Now check the DB!
    [db_user] = Account.list_users(search: [name: name], joins: [:groups])
    assert Enum.count(db_user.groups) == 1
  end

  test "LOGIN", %{socket: socket} do
    username = "new_test_user_raw"

    # We expect to be greeted by a welcome message
    reply = _recv_raw(socket)
    assert reply == "TASSERVER 0.38-33-ga5f3b28 * 8201 0\n"

    _send_raw(socket, "REGISTER #{username} X03MO1qnZdYdgyfeuILPmQ== #{username}@email\n")
    _ = _recv_raw(socket)
    user = User.get_user_by_name(username)
    assert user != nil
    User.update_user(%{user | verified: true})

    _send_raw(
      socket,
      "LOGIN #{username} X03MO1qnZdYdgyfeuILPmQ== 0 * LuaLobby Chobby\t1993717506\t0d04a635e200f308\tb sp\n"
    )

    reply = _recv_until(socket)
    [accepted | remainder] = String.split(reply, "\n")
    user = User.get_user_by_name(username)

    assert accepted == "ACCEPTED #{username}",
      message:
        "Bad password, gave X03MO1qnZdYdgyfeuILPmQ== but needed #{user.password_hash}. Accepted message is #{
          accepted
        }"

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

    _send_raw(socket, "EXIT\n")
    _ = _recv_raw(socket)

    # Is it actually killed?
    {:error, :enotconn} = :gen_tcp.recv(socket, 0, 1000)
  end

  test "CONFIRMAGREEMENT", %{socket: socket} do
    user = new_user()
    user = User.update_user(%{user | verification_code: 123456, verified: false}, persist: true)
    query = "UPDATE account_users SET inserted_at = '2020-01-01 01:01:01' WHERE id = #{user.id}"
    Ecto.Adapters.SQL.query(Repo, query, [])
    Teiserver.User.recache_user(user.id)
    _ = _recv_raw(socket)

    # If we try to login as them we should get a specific failure
    _send_raw(socket, "LOGIN #{user.name} X03MO1qnZdYdgyfeuILPmQ== 0 * LuaLobby Chobby\t1993717506\t0d04a635e200f308\tb sp\n")
    reply = _recv_raw(socket)
    assert reply =~ "AGREEMENT User agreement goes here.\nAGREEMENT \nAGREEMENTEND\n"

    # Verify user - bad code
    _send_raw(socket, "CONFIRMAGREEMENT 000000000\n")
    reply = _recv_raw(socket)
    assert reply =~ "DENIED Incorrect code\n"

    # Verify user - good code
    _send_raw(socket, "CONFIRMAGREEMENT 123456\n")
    reply = _recv_raw(socket)
    assert reply =~ "ACCEPTED #{user.name}\n"
    assert reply =~ "MOTD Message of the day\n"
    assert reply =~ "LOGININFOEND\n"
  end

  test "RESETPASSWORDREQUEST", %{socket: socket} do
    user = new_user()
    _ = _recv_raw(socket)

    # Send the wrong request
    _send_raw(
      socket,
      "RESETPASSWORDREQUEST not_an_email\n"
    )

    reply = _recv_raw(socket)
    assert reply =~ "RESETPASSWORDREQUESTDENIED user error\n"

    # Send the correct request
    _send_raw(
      socket,
      "RESETPASSWORDREQUEST #{user.email}\n"
    )

    # We now send an email instead of using the password reset code
    # assert user.password_reset_code == nil
    # user2 = User.get_user_by_id(user.id)
    # assert user2.password_reset_code != nil
    reply = _recv_raw(socket)
    assert reply =~ "RESETPASSWORDREQUESTACCEPTED\n"
    # user = user2

    # # Now verify badly
    # _send_raw(
    #   socket,
    #   "RESETPASSWORD #{user.email} the_wrong_code\n"
    # )

    # reply = _recv_raw(socket)
    # assert reply =~ "RESETPASSWORDDENIED wrong_code\n"
    # user2 = User.get_user_by_id(user.id)
    # assert user2.password_hash == user.password_hash

    # # Now verify correctly
    # _send_raw(
    #   socket,
    #   "RESETPASSWORD #{user.email} #{user.password_reset_code}\n"
    # )

    # reply = _recv_raw(socket)
    # assert reply == "RESETPASSWORDACCEPTED\n"
    # user2 = User.get_user_by_id(user.id)
    # assert user2.password_hash != user.password_hash
    # assert user2.password_reset_code == nil
  end

  # TODO - Implement STLS and find a way to test it
  # test "STLS" do
  #   flunk("Not tested")
  # end

  test "login flood protection", %{socket: socket} do
    user = new_user()

    # Update the login count
    ConCache.put(:teiserver_login_count, user.id, 9999)

    # Welcome message
    _recv_raw(socket)

    _send_raw(
      socket,
      "LOGIN #{user.name} X03MO1qnZdYdgyfeuILPmQ== 0 * LuaLobby Chobby\t1993717506\t0d04a635e200f308\tb sp\n"
    )

    reply = _recv_until(socket)
    assert reply == "DENIED Flood protection - Please wait 20 seconds and try again\n"
  end
end
