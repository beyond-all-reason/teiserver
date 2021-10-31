defmodule Teiserver.Protocols.TachyonRawTest do
  use Central.ServerCase

  alias Teiserver.User

  import Teiserver.TeiserverTestLib,
    only: [tls_setup: 0, _send_raw: 2, _tachyon_send: 2, _recv_raw: 1, _tachyon_recv: 1, new_user: 0, new_user_name: 0]

  alias Teiserver.Protocols.Tachyon

  setup do
    %{socket: socket} = tls_setup()
    {:ok, socket: socket}
  end

  test "spring tachyon interop command", %{socket: socket} do
    _ = _recv_raw(socket)
    cmd = %{cmd: "c.system.ping"}
    data = Tachyon.encode(cmd)
    _send_raw(socket, "TACHYON #{data}\n")
    reply = _tachyon_recv(socket)
    assert reply == %{"cmd" => "s.system.pong"}
  end

  test "swap to tachyon", %{socket: socket} do
    # Test it swaps to it
    _ = _recv_raw(socket)
    _send_raw(socket, "TACHYON\n")
    reply = _recv_raw(socket)
    assert reply =~ "OK cmd=TACHYON\n"

    # Now test we can ping it
    cmd = %{cmd: "c.system.ping"}
    data = Tachyon.encode(cmd)
    _send_raw(socket, data <> "\n")
    reply = _tachyon_recv(socket)
    assert reply == %{"cmd" => "s.system.pong"}

    # With msg_id
    cmd = %{cmd: "c.system.ping", msg_id: 123_456}
    data = Tachyon.encode(cmd)
    _send_raw(socket, data <> "\n")
    reply = _tachyon_recv(socket)
    assert reply == %{"cmd" => "s.system.pong", "msg_id" => 123_456}

    # Test we can send it bad data and it won't crash
    data =
      "This is not valid json at all"
      |> :zlib.gzip()
      |> Base.encode64()

    resp = _send_raw(socket, data <> "\n")
    assert resp == :ok
    reply = _tachyon_recv(socket)
    assert reply == %{"result" => "error", "error" => "bad_json", "location" => "decode"}

    data =
      "This is not gzipped"
      |> Base.encode64()

    resp = _send_raw(socket, data <> "\n")
    assert resp == :ok
    reply = _tachyon_recv(socket)
    assert reply == %{"result" => "error", "error" => "gzip_decompress", "location" => "decode"}

    data = "This is probably not base64"
    resp = _send_raw(socket, data <> "\n")
    assert resp == :ok
    reply = _tachyon_recv(socket)
    assert reply == %{"result" => "error", "error" => "base64_decode", "location" => "decode"}
  end

  test "register and auth", %{socket: socket} do
    # Swap to Tachyon
    _ = _recv_raw(socket)
    _send_raw(socket, "TACHYON\n")
    reply = _recv_raw(socket)
    assert reply =~ "OK cmd=TACHYON\n"

    # Lets start with a bad register command
    existing_user = new_user()
    data = %{cmd: "c.auth.register", username: "test_name", email: existing_user.email, password: "password"}
    _tachyon_send(socket, data)
    reply = _tachyon_recv(socket)
    assert reply == %{"cmd" => "s.auth.register", "result" => "failure", "reason" => "User already exists"}

    # Now a good one
    name = new_user_name()
    data = %{cmd: "c.auth.register", username: name, email: "tachyon_register@example", password: "password"}
    _tachyon_send(socket, data)
    reply = _tachyon_recv(socket)
    assert reply == %{"cmd" => "s.auth.register", "result" => "success"}

    db_user =  Teiserver.Account.get_user(nil, search: [email: "tachyon_register@example"])
    assert db_user != nil

    cache_user_email = User.get_user_by_email("tachyon_register@example")
    cache_user_id = User.get_user_by_id(db_user.id)
    assert cache_user_email == cache_user_id

    User.verify_user(cache_user_id)
    User.recache_user(db_user.id)
    user = User.get_user_by_id(db_user.id)

    # Bad password but also test msg_id continuance
    data = %{cmd: "c.auth.get_token", password: "bad_password", email: user.email, msg_id: 555}
    _tachyon_send(socket, data)
    reply = _tachyon_recv(socket)
    assert reply == %{"cmd" => "s.auth.get_token", "result" => "failure", "reason" => "Invalid credentials", "msg_id" => 555}

    # Good password
    data = %{cmd: "c.auth.get_token", password: "password", email: user.email}
    _tachyon_send(socket, data)
    reply = _tachyon_recv(socket)
    assert Map.has_key?(reply, "token")
    token = reply["token"]
    assert reply == %{"cmd" => "s.auth.get_token", "result" => "success", "token" => token}

    # Now do the login, it should work as we only just created the user
    data = %{cmd: "c.auth.login", token: token, lobby_name: "ex_test", lobby_version: "1a", lobby_hash: "t1 t2"}
    _tachyon_send(socket, data)
    reply = _tachyon_recv(socket)
    assert match?(%{"cmd" => "s.auth.login", "result" => "success"}, reply)
  end

  test "register, verify and auth", %{socket: socket} do
    # Swap to Tachyon
    _ = _recv_raw(socket)
    _send_raw(socket, "TACHYON\n")
    reply = _recv_raw(socket)
    assert reply =~ "OK cmd=TACHYON\n"

    # Create the user
    name = new_user_name()
    data = %{cmd: "c.auth.register", username: name, email: "tachyon_verify@example", password: "password"}
    _tachyon_send(socket, data)
    reply = _tachyon_recv(socket)
    assert reply == %{"cmd" => "s.auth.register", "result" => "success"}

    user = User.get_user_by_email("tachyon_verify@example")
    User.update_user(%{user | verification_code: "123456"})

    # Bad password but also test msg_id continuance
    data = %{cmd: "c.auth.get_token", password: "bad_password", email: user.email, msg_id: 555}
    _tachyon_send(socket, data)
    reply = _tachyon_recv(socket)
    assert reply == %{"cmd" => "s.auth.get_token", "result" => "failure", "reason" => "Invalid credentials", "msg_id" => 555}

    # Good password
    data = %{cmd: "c.auth.get_token", password: "password", email: user.email}
    _tachyon_send(socket, data)
    reply = _tachyon_recv(socket)
    assert Map.has_key?(reply, "token")
    token = reply["token"]
    assert reply == %{"cmd" => "s.auth.get_token", "result" => "success", "token" => token}

    # Now do the login
    data = %{cmd: "c.auth.login", token: token, lobby_name: "ex_test", lobby_version: "1a", lobby_hash: "t1 t2"}
    _tachyon_send(socket, data)
    reply = _tachyon_recv(socket)
    assert reply == %{"cmd" => "s.auth.login", "result" => "unverified", "agreement" => "User agreement goes here."}

    # Verify - bad token
    data = %{cmd: "c.auth.verify", token: "aaaa", code: "1a"}
    _tachyon_send(socket, data)
    reply = _tachyon_recv(socket)
    assert reply == %{"cmd" => "s.auth.verify", "result" => "failure", "reason" => "bad token"}

    # Verify - bad code
    data = %{cmd: "c.auth.verify", token: token, code: "1a"}
    _tachyon_send(socket, data)
    reply = _tachyon_recv(socket)
    assert reply == %{"cmd" => "s.auth.verify", "result" => "failure", "reason" => "bad code"}

    # Verify - good code
    data = %{cmd: "c.auth.verify", token: token, code: "123456"}
    _tachyon_send(socket, data)
    reply = _tachyon_recv(socket)
    assert Map.has_key?(reply, "user")
    assert reply["user"]["id"] == user.id
    assert match?(%{"cmd" => "s.auth.verify", "result" => "success"}, reply)

    # Disconnect
    data = %{cmd: "c.auth.disconnect"}
    _tachyon_send(socket, data)
    _tachyon_recv(socket)
  end

  test "auth existing user", %{socket: socket} do
    # Swap to Tachyon
    _ = _recv_raw(socket)
    _send_raw(socket, "TACHYON\n")
    reply = _recv_raw(socket)
    assert reply =~ "OK cmd=TACHYON\n"

    # Create the user
    name = new_user_name()
    data = %{cmd: "c.auth.register", username: name, email: "tachyon_existing@example", password: "token_password"}
    _tachyon_send(socket, data)
    reply = _tachyon_recv(socket)
    assert reply == %{"cmd" => "s.auth.register", "result" => "success"}

    user = User.get_user_by_email("tachyon_existing@example")
    User.verify_user(user)

    # Bad password but also test msg_id continuance
    data = %{cmd: "c.auth.get_token", password: "bad_password", email: user.email, msg_id: 555}
    _tachyon_send(socket, data)
    reply = _tachyon_recv(socket)
    assert reply == %{"cmd" => "s.auth.get_token", "result" => "failure", "reason" => "Invalid credentials", "msg_id" => 555}

    # Good password
    data = %{cmd: "c.auth.get_token", password: "token_password", email: user.email}
    _tachyon_send(socket, data)
    reply = _tachyon_recv(socket)
    assert Map.has_key?(reply, "token")
    token = reply["token"]
    assert reply == %{"cmd" => "s.auth.get_token", "result" => "success", "token" => token}

    # Login - bad token
    data = %{cmd: "c.auth.login", token: "ab", lobby_name: "ex_test", lobby_version: "1a", lobby_hash: "t1 t2"}
    _tachyon_send(socket, data)
    reply = _tachyon_recv(socket)
    assert reply == %{"cmd" => "s.auth.login", "result" => "failure", "reason" => "token_login_failed"}

    # Login - good token
    data = %{cmd: "c.auth.login", token: token, lobby_name: "ex_test", lobby_version: "1a", lobby_hash: "t1 t2"}
    _tachyon_send(socket, data)
    reply = _tachyon_recv(socket)
    assert Map.has_key?(reply, "user")
    assert reply["user"]["id"] == user.id
    assert match?(%{"cmd" => "s.auth.login", "result" => "success"}, reply)

    # Now disconnect
    data = %{cmd: "c.auth.disconnect"}
    _tachyon_send(socket, data)
    _tachyon_recv(socket)
  end
end
