defmodule Barserver.Protocols.Spring.SpringBattleHostAsyncTest do
  use Barserver.ServerCase, async: true
  alias Barserver.Protocols.Spring
  alias Barserver.Client

  import Barserver.BarserverTestLib,
    only: [
      async_auth_setup: 1,
      _send_lines: 2,
      _recv_lines: 0
    ]

  setup do
    %{user: user, state: state} = async_auth_setup(Spring)
    on_exit(fn -> teardown(user) end)
    {:ok, state: state, user: user}
  end

  defp teardown(user) do
    Client.disconnect(user.id)
  end

  test "battle commands when not in a battle", %{state: state} do
    _send_lines(state, "LEAVEBATTLE\n")
    reply = _recv_lines()
    assert reply == ""

    _send_lines(state, "MYBATTLESTATUS 123 123\n")
    reply = _recv_lines()
    assert reply == ""
  end
end
