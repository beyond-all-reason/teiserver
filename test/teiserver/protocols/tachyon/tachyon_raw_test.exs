defmodule Teiserver.Protocols.TachyonRawTest do
  use Central.ServerCase, async: false

  alias Teiserver.TestLib

  import Teiserver.TestLib,
    only: [raw_setup: 0]

  alias Teiserver.Protocols.Tachyon
  alias Central.Account

  setup do
    %{socket: socket} = raw_setup()
    {:ok, socket: socket}
  end

  defp _send(socket, data) do
    TestLib._send(socket, data <> "\n")
  end

  defp _recv(socket) do
    case TestLib._recv(socket) do
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
    _ = TestLib._recv(socket)
    _send(socket, "TACHYON\n")
    reply = TestLib._recv(socket)
    assert reply =~ "OK cmd=TACHYON\n"

    # Now test we can ping it
    cmd = %{cmd: "PING"}
    data = Tachyon.encode(cmd)
    _send(socket, data)
    reply = _recv(socket)
    assert reply == %{"cmd" => "PONG"}

    # With msg_id
    cmd = %{cmd: "PING", msg_id: 123_456}
    data = Tachyon.encode(cmd)
    _send(socket, data)
    reply = _recv(socket)
    assert reply == %{"cmd" => "PONG", "msg_id" => 123_456}

    # Test we can send it bad data and it won't crash
    data =
      "This is not valid json at all"
      |> :zlib.gzip()
      |> Base.encode64()

    resp = _send(socket, data)
    assert resp == :ok
    reply = _recv(socket)
    assert reply == %{"cmd" => "ERROR", "error" => "bad_json", "location" => "decode"}

    data =
      "This is not gzipped"
      |> Base.encode64()

    resp = _send(socket, data)
    assert resp == :ok
    reply = _recv(socket)
    assert reply == %{"cmd" => "ERROR", "error" => "gzip_decompress", "location" => "decode"}

    data = "This is probably not base64"
    resp = _send(socket, data)
    assert resp == :ok
    reply = _recv(socket)
    assert reply == %{"cmd" => "ERROR", "error" => "base64_decode", "location" => "decode"}
  end
end
