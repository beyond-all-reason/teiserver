defmodule Teiserver.SpringAuthTest do
  use ExUnit.Case
  import Teiserver.TestLib, only: [auth_setup: 0, _send: 2, _recv: 1]

  setup do
    auth_setup()
  end

  test "ping", %{socket: socket} do
    _send(socket, "#4 PING\n")
    reply = _recv(socket)
    assert reply == "#4 PONG\n"
  end
end