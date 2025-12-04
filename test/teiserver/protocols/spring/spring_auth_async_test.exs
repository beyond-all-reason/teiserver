defmodule Teiserver.SpringAuthAsyncTest do
  use Teiserver.ServerCase, async: false
  alias Teiserver.Client
  alias Teiserver.Protocols.SpringIn

  import Teiserver.TeiserverTestLib,
    only: [
      async_auth_setup: 0,
      _recv_lines: 0,
      _recv_lines: 1
    ]

  setup do
    %{user: user, state: state} = async_auth_setup()
    {:ok, state: state, user: user}
  end

  defp teardown(user) do
    Client.disconnect(user.id)
  end

  test "PING", %{state: state, user: user} do
    SpringIn.data_in("#4 PING\n", state)
    reply = _recv_lines()
    teardown(user)
    assert reply == "#4 PONG\n"
  end

  test "GETUSERINFO", %{state: state, user: user} do
    SpringIn.data_in("GETUSERINFO\n", state)
    reply = _recv_lines(3)
    teardown(user)
    assert reply =~ "SERVERMSG Registration date: "
    assert reply =~ "SERVERMSG Email address: #{user.email}"
    assert reply =~ "SERVERMSG Ingame time: "
  end
end
