defmodule Teiserver.Protocols.TachyonRawTest do
  use Central.ServerCase, async: false

  alias Central.Helpers.GeneralTestLib
  alias Teiserver.TeiserverTestLib

  import Teiserver.TeiserverTestLib,
    only: [raw_setup: 0]

  alias Teiserver.Protocols.Tachyon

  setup do
    %{socket: socket} = raw_setup()
    {:ok, socket: socket}
  end

  defp _send(socket, data) do
    TeiserverTestLib._send(socket, data <> "\n")
  end

  defp _recv(socket) do
    case TeiserverTestLib._recv(socket) do
      :timeout ->
        :timeout

      resp ->
        case Tachyon.decode(resp) do
          {:ok, msg} -> msg
          error -> error
        end
    end
  end

  test "swap to tachyon", %{socket: socket} do
    # Test it swaps to it
    _ = TeiserverTestLib._recv(socket)
    _send(socket, "TACHYON\n")
    reply = TeiserverTestLib._recv(socket)
    assert reply =~ "OK cmd=TACHYON\n"

    # Now test we can ping it
    cmd = %{cmd: "c.system.ping"}
    data = Tachyon.encode(cmd)
    _send(socket, data)
    reply = _recv(socket)
    assert reply == %{"cmd" => "s.system.pong"}

    # With msg_id
    cmd = %{cmd: "c.system.ping", msg_id: 123_456}
    data = Tachyon.encode(cmd)
    _send(socket, data)
    reply = _recv(socket)
    assert reply == %{"cmd" => "s.system.pong", "msg_id" => 123_456}

    # Test we can send it bad data and it won't crash
    data =
      "This is not valid json at all"
      |> :zlib.gzip()
      |> Base.encode64()

    resp = _send(socket, data)
    assert resp == :ok
    reply = _recv(socket)
    assert reply == %{"result" => "error", "error" => "bad_json", "location" => "decode"}

    data =
      "This is not gzipped"
      |> Base.encode64()

    resp = _send(socket, data)
    assert resp == :ok
    reply = _recv(socket)
    assert reply == %{"result" => "error", "error" => "gzip_decompress", "location" => "decode"}

    data = "This is probably not base64"
    resp = _send(socket, data)
    assert resp == :ok
    reply = _recv(socket)
    assert reply == %{"result" => "error", "error" => "base64_decode", "location" => "decode"}
  end

  test "register and auth", %{socket: socket} do
    # Swap to Tachyon
    _ = TeiserverTestLib._recv(socket)
    _send(socket, "TACHYON\n")
    reply = TeiserverTestLib._recv(socket)
    assert reply =~ "OK cmd=TACHYON\n"

    # Not actually registering just yet since that's not implemented...

    # Create the user manually for now
    user =
      GeneralTestLib.make_user(%{
        "name" => "tachyon_token_test_user",
        "email" => "tachyon_token_test_user@",
        "password" => "token_password",
        "data" => %{
          "verified" => true
        }
      })

    # Bad password but also test msg_id continuance
    cmd = %{cmd: "c.auth.get_token", password: "bad_password", email: user.email, msg_id: 555}
    data = Tachyon.encode(cmd)
    _send(socket, data)
    reply = _recv(socket)
    assert reply == %{"cmd" => "s.auth.get_token", "outcome" => "failure", "reason" => "Invalid credentials", "msg_id" => 555}

    # Good password
    cmd = %{cmd: "c.auth.get_token", password: "token_password", email: user.email}
    data = Tachyon.encode(cmd)
    _send(socket, data)
    reply = _recv(socket)
    assert Map.has_key?(reply, "token")
    assert reply == %{"cmd" => "s.auth.get_token", "outcome" => "success", "token" => reply["token"]}
  end
end
