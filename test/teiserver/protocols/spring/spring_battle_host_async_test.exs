defmodule Teiserver.Protocols.Spring.SpringBattleHostAsyncTest do
  use Teiserver.ServerCase, async: true
  alias Teiserver.Protocols.Spring
  alias Teiserver.Client

  import Teiserver.TeiserverTestLib,
    only: [
      async_auth_setup: 1,
      _send_lines: 2,
      _recv_lines: 0
    ]

  setup do
    %{user: user, state: state} = async_auth_setup(Spring)
    {:ok, state: state, user: user}
  end

  defp teardown(user) do
    Client.disconnect(user.id)
  end

  test "battle commands when not in a battle", %{state: state, user: user} do
    _send_lines(state, "LEAVEBATTLE\n")
    reply = _recv_lines()
    assert reply == ""

    _send_lines(state, "MYBATTLESTATUS 123 123\n")
    reply = _recv_lines()
    teardown(user)
    assert reply == ""
  end
end
