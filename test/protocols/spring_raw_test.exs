defmodule Teiserver.SpringRawTest do
  use ExUnit.Case
  import Teiserver.TestLib, only: [raw_setup: 0, _send: 2, _recv: 1]
  alias Teiserver.User

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

  test "REGISTER", %{socket: socket} do
    _ = _recv(socket)

    # Failure first
    _send(socket, "REGISTER TestUser\tpassword\temail\n")
    reply = _recv(socket)
    assert reply == "REGISTRATIONDENIED User already exists\n"

    # Success second
    _send(socket, "REGISTER NewUser\tpassword\temail\n")
    reply = _recv(socket)
    assert reply == "REGISTRATIONACCEPTED\n"
    user = User.get_user_by_name("NewUser")
    assert user != nil
  end
end
