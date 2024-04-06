defmodule Teiserver.SpringAuthAsyncTest do
  use Teiserver.ServerCase, async: true
  alias Teiserver.Client
  alias Teiserver.Protocols.Spring

  import Teiserver.TeiserverTestLib,
    only: [
      async_auth_setup: 1,
      _send_lines: 2,
      _recv_lines: 0,
      _recv_lines: 1
    ]

  setup do
    %{user: user, state: state} = async_auth_setup(Spring)
    {:ok, state: state, user: user}
  end

  defp teardown(user) do
    Client.disconnect(user.id)
  end

  test "PING", %{state: state, user: user} do
    _send_lines(state, "#4 PING\n")
    reply = _recv_lines()
    teardown(user)
    assert reply == "#4 PONG\n"
  end

  test "GETUSERINFO", %{state: state, user: user} do
    _send_lines(state, "GETUSERINFO\n")
    reply = _recv_lines(3)
    teardown(user)
    assert reply =~ "SERVERMSG Registration date: "
    assert reply =~ "SERVERMSG Email address: #{user.email}"
    assert reply =~ "SERVERMSG Ingame time: "
  end
end
