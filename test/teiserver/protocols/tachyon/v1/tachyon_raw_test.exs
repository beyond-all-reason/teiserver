defmodule Teiserver.Protocols.V1.TachyonRawTest do
  use Central.ServerCase

  alias Teiserver.{User, Account}

  import Teiserver.TeiserverTestLib,
    only: [spring_tls_setup: 0, tachyon_tls_setup: 0, raw_setup: 0, _send_raw: 2, _tachyon_send: 2, _recv_raw: 1, _tachyon_recv: 1, new_user: 0, new_user_name: 0, _recv_until: 1]

  alias Teiserver.Protocols.TachyonLib

  setup do
    %{socket: socket} = tachyon_tls_setup()
    {:ok, socket: socket}
  end

  test "spring tachyon interop command" do
    %{socket: socket} = spring_tls_setup()
    _ = _recv_raw(socket)
    cmd = %{cmd: "c.system.ping"}
    data = TachyonLib.encode(cmd)
    _send_raw(socket, "TACHYON #{data}\n")
    [reply] = _tachyon_recv(socket)
    assert reply["cmd"] == "s.system.pong"
  end

  test "basic tachyon", %{socket: socket} do
    # Now test we can ping it
    cmd = %{cmd: "c.system.ping"}
    data = TachyonLib.encode(cmd)
    _send_raw(socket, data <> "\n")
    [reply] = _tachyon_recv(socket)
    assert reply["cmd"] == "s.system.pong"

    # With msg_id
    cmd = %{cmd: "c.system.ping", msg_id: 123_456}
    data = TachyonLib.encode(cmd)
    _send_raw(socket, data <> "\n")
    [reply] = _tachyon_recv(socket)
    assert reply["cmd"] == "s.system.pong"
    assert reply["msg_id"] == 123_456

    # Test we can send it bad data and it won't crash
    data =
      "This is not valid json at all"
      |> :zlib.gzip()
      |> Base.encode64()

    resp = _send_raw(socket, data <> "\n")
    assert resp == :ok
    reply = _tachyon_recv(socket)
    assert reply == [%{"result" => "error", "error" => "bad_json", "location" => "decode"}]

    data =
      "This is not gzipped"
      |> Base.encode64()

    resp = _send_raw(socket, data <> "\n")
    assert resp == :ok
    reply = _tachyon_recv(socket)
    assert reply == [%{"result" => "error", "error" => "gzip_decompress", "location" => "decode"}]

    data = "This is probably not base64"
    resp = _send_raw(socket, data <> "\n")
    assert resp == :ok
    reply = _tachyon_recv(socket)
    assert reply == [%{"result" => "error", "error" => "base64_decode", "location" => "decode"}]
  end

  test "register and auth", %{socket: socket} do
    # Lets start with a bad register command
    existing_user = new_user()
    data = %{cmd: "c.auth.register", username: "test_name", email: existing_user.email, password: "password"}
    _tachyon_send(socket, data)
    reply = _tachyon_recv(socket)
    assert reply == [%{"cmd" => "s.auth.register", "result" => "failure", "reason" => "Email already in use"}]

    # Now a good one
    name = new_user_name()
    data = %{cmd: "c.auth.register", username: name, email: "tachyon_register@example.e", password: "password"}
    _tachyon_send(socket, data)
    reply = _tachyon_recv(socket)
    assert reply == [%{"cmd" => "s.auth.register", "result" => "success"}]

    db_user =  Account.get_user(nil, search: [email: "tachyon_register@example.e"])
    assert db_user != nil

    cache_user_email = User.get_user_by_email("tachyon_register@example.e")
    cache_user_id = User.get_user_by_id(db_user.id)
    assert cache_user_email == cache_user_id

    User.verify_user(cache_user_id)
    User.recache_user(db_user.id)
    user = User.get_user_by_id(db_user.id)

    # Bad password but also test msg_id continuance
    data = %{cmd: "c.auth.get_token", password: "bad_password", email: user.email, msg_id: 555}
    _tachyon_send(socket, data)
    reply = _tachyon_recv(socket)
    assert reply == [%{"cmd" => "s.auth.get_token", "result" => "failure", "reason" => "Invalid credentials", "msg_id" => 555}]

    # Good password
    data = %{cmd: "c.auth.get_token", password: "password", email: user.email}
    _tachyon_send(socket, data)
    [reply] = _tachyon_recv(socket)
    assert Map.has_key?(reply, "token")
    token = reply["token"]
    assert reply == %{"cmd" => "s.auth.get_token", "result" => "success", "token" => token}

    # Now do the login, it should work as we only just created the user
    data = %{cmd: "c.auth.login", token: token, lobby_name: "ex_test", lobby_version: "1a", lobby_hash: "t1 t2"}
    _tachyon_send(socket, data)
    reply = _tachyon_recv(socket)
    assert match?([%{"cmd" => "s.auth.login", "result" => "success"}], reply)
    [reply] = reply
    assert Map.has_key?(reply["user"], "icons")
  end

  test "register, verify and auth", %{socket: socket} do
    # Create the user
    name = new_user_name()
    data = %{cmd: "c.auth.register", username: name, email: "tachyon_verify@example.e", password: "password"}
    _tachyon_send(socket, data)
    reply = _tachyon_recv(socket)
    assert reply == [%{"cmd" => "s.auth.register", "result" => "success"}]

    user = User.get_user_by_email("tachyon_verify@example.e")
    Account.update_user_stat(user.id, %{"verification_code" => "123456"})

    # Bad password but also test msg_id continuance
    data = %{cmd: "c.auth.get_token", password: "bad_password", email: user.email, msg_id: 555}
    _tachyon_send(socket, data)
    reply = _tachyon_recv(socket)
    assert reply == [%{"cmd" => "s.auth.get_token", "result" => "failure", "reason" => "Invalid credentials", "msg_id" => 555}]

    # Good password
    data = %{cmd: "c.auth.get_token", password: "password", email: user.email}
    _tachyon_send(socket, data)
    [reply] = _tachyon_recv(socket)
    assert Map.has_key?(reply, "token")
    token = reply["token"]
    assert reply == %{"cmd" => "s.auth.get_token", "result" => "success", "token" => token}

    # Now do the login
    data = %{cmd: "c.auth.login", token: token, lobby_name: "ex_test", lobby_version: "1a", lobby_hash: "t1 t2"}
    _tachyon_send(socket, data)
    reply = _tachyon_recv(socket)
    assert reply == [%{"cmd" => "s.auth.login", "result" => "unverified", "agreement" => "User agreement goes here."}]

    # Verify - bad token
    data = %{cmd: "c.auth.verify", token: "aaaa", code: "1a"}
    _tachyon_send(socket, data)
    reply = _tachyon_recv(socket)
    assert reply == [%{"cmd" => "s.auth.verify", "result" => "failure", "reason" => "bad token"}]

    # Verify - bad code
    data = %{cmd: "c.auth.verify", token: token, code: "1a"}
    _tachyon_send(socket, data)
    reply = _tachyon_recv(socket)
    assert reply == [%{"cmd" => "s.auth.verify", "result" => "failure", "reason" => "bad code"}]

    # Verify - good code
    data = %{cmd: "c.auth.verify", token: token, code: "123456"}
    _tachyon_send(socket, data)
    [reply] = _tachyon_recv(socket)
    assert Map.has_key?(reply, "user")
    assert reply["user"]["id"] == user.id
    assert match?(%{"cmd" => "s.auth.verify", "result" => "success"}, reply)
    assert Map.has_key?(reply["user"], "icons")

    # Disconnect
    data = %{cmd: "c.auth.disconnect"}
    _tachyon_send(socket, data)
    _tachyon_recv(socket)
  end

  test "auth existing user", %{socket: socket} do
    # Create the user
    name = new_user_name()
    data = %{cmd: "c.auth.register", username: name, email: "tachyon_existing@example.e", password: "token_password"}
    _tachyon_send(socket, data)
    reply = _tachyon_recv(socket)
    assert reply == [%{"cmd" => "s.auth.register", "result" => "success"}]

    user = User.get_user_by_email("tachyon_existing@example.e")
    User.verify_user(user)

    # Bad password but also test msg_id continuance
    data = %{cmd: "c.auth.get_token", password: "bad_password", email: user.email, msg_id: 555}
    _tachyon_send(socket, data)
    reply = _tachyon_recv(socket)
    assert reply == [%{"cmd" => "s.auth.get_token", "result" => "failure", "reason" => "Invalid credentials", "msg_id" => 555}]

    # Good password
    data = %{cmd: "c.auth.get_token", password: "token_password", email: user.email}
    _tachyon_send(socket, data)
    [reply] = _tachyon_recv(socket)
    assert Map.has_key?(reply, "token")
    token = reply["token"]
    assert reply == %{"cmd" => "s.auth.get_token", "result" => "success", "token" => token}

    # Login - bad token
    data = %{cmd: "c.auth.login", token: "ab", lobby_name: "ex_test", lobby_version: "1a", lobby_hash: "t1 t2"}
    _tachyon_send(socket, data)
    reply = _tachyon_recv(socket)
    assert reply == [%{"cmd" => "s.auth.login", "result" => "failure", "reason" => "token_login_failed"}]

    # Login - good token
    data = %{cmd: "c.auth.login", token: token, lobby_name: "ex_test", lobby_version: "1a", lobby_hash: "t1 t2"}
    _tachyon_send(socket, data)
    [reply] = _tachyon_recv(socket)
    assert Map.has_key?(reply, "user")
    assert reply["user"]["id"] == user.id
    assert match?(%{"cmd" => "s.auth.login", "result" => "success"}, reply)

    # Now disconnect
    data = %{cmd: "c.auth.disconnect"}
    _tachyon_send(socket, data)
    _tachyon_recv(socket)
  end

  test "existing spring user" do
    md5_pass = User.spring_md5_password("password")

    # Create the user
    username = new_user_name()
    {:ok, user} = Account.create_user(%{
      name: username,
      email: "#{username}@email",
      password: md5_pass,
      permissions: [],
      admin_group_id: Teiserver.user_group_id(),
      colour: "#AA0000",
      icon: "fa-solid fa-user",
      data: %{
        "bot" => false,
        "moderator" => false,
        "verified" => true,
        "springid" => 123,
      }
    })
    userid = user.id
    user = Account.get_user!(userid)

    new_data =
      Map.merge(user.data, %{
        "password_hash" => user.password |> String.replace("\"", ""),
        "spring_password" => true
      })
    Account.update_user(user, %{data: new_data})
    User.recache_user(userid)

    # Lets save the md5'd password
    old_db_hash = user.password

    # First login with spring to make sure we're doing it right
    %{socket: raw_socket} = raw_setup()

    # We expect to be greeted by a welcome message
    reply = _recv_raw(raw_socket)
    assert reply == "TASSERVER 0.38-33-ga5f3b28 * 8201 0\n"

    _send_raw(
      raw_socket,
      "LOGIN #{username} #{md5_pass} 0 * LuaLobby Chobby\t1993717506 0d04a635e200f308\tb sp\n"
    )

    reply = _recv_until(raw_socket)
    [accepted | _remainder] = String.split(reply, "\n")

    assert accepted == "ACCEPTED #{username}",
      message:
        "Bad password, gave X03MO1qnZdYdgyfeuILPmQ== but needed #{user.data["password_hash"]}. Accepted message is #{
          accepted
        }"

    # Check the user password hasn't changed
    user = Account.get_user!(userid)
    assert user.password == old_db_hash
    assert user.data["password_hash"] == old_db_hash
    assert user.data["spring_password"] == true

    # Disconnect
    _send_raw(raw_socket, "EXIT\n")

    # Swap to Tachyon
    %{socket: tls_socket} = tachyon_tls_setup()

    # Now auth via Tachyon
    # Good password
    _tachyon_send(tls_socket, %{cmd: "c.auth.get_token", password: "password", email: user.email})
    # We have a sleep here because on a slower computer the tests can fail as
    # the password hash takes a bit longer

    [reply] = _tachyon_recv(tls_socket)
    assert Map.has_key?(reply, "token")
    token = reply["token"]
    assert reply == %{"cmd" => "s.auth.get_token", "result" => "success", "token" => token}

    # Check the user password has changed but their password_hash in the data field hasn't
    user = Account.get_user!(userid)
    assert user.password != old_db_hash
    assert user.data["password_hash"] == old_db_hash
    assert user.data["spring_password"] == false

    # Disconnect
    _tachyon_send(tls_socket, %{cmd: "c.auth.disconnect"})

    # Can we reconnect? It should no longer be a spring password
    %{socket: tls_socket} = tachyon_tls_setup()

    _tachyon_send(tls_socket, %{cmd: "c.auth.get_token", password: "password", email: user.email})
    [reply] = _tachyon_recv(tls_socket)
    assert Map.has_key?(reply, "token")
    token = reply["token"]
    assert reply == %{"cmd" => "s.auth.get_token", "result" => "success", "token" => token}

    # # Disconnect
    _tachyon_send(tls_socket, %{cmd: "c.auth.disconnect"})

    # What about with spring?
    %{socket: raw_socket} = raw_setup()

    # We expect to be greeted by a welcome message
    reply = _recv_raw(raw_socket)
    assert reply == "TASSERVER 0.38-33-ga5f3b28 * 8201 0\n"

    _send_raw(
      raw_socket,
      "LOGIN #{username} #{md5_pass} 0 * LuaLobby Chobby\t1993717506 0d04a635e200f308\tb sp\n"
    )

    reply = _recv_until(raw_socket)
    [accepted | _remainder] = String.split(reply, "\n")

    assert accepted == "ACCEPTED #{username}",
      message:
        "Bad password, gave X03MO1qnZdYdgyfeuILPmQ== but needed #{user.data["password_hash"]}. Accepted message is #{
          accepted
        }"
  end
end
