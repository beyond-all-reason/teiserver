defmodule Teiserver.SpringRawTest do
  use ExUnit.Case
  import Teiserver.TestLib, only: [raw_setup: 0, _send: 2, _recv: 1]

  setup do
    %{socket: socket} = raw_setup()
    {:ok, socket: socket}
  end

  test "ping", %{socket: socket} do
    _ = _recv(socket)
    _send(socket, "#4 PING\n")
    reply = _recv(socket)
    assert reply == "#4 PONG\n"
  end
end