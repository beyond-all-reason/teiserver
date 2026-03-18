defmodule Teiserver.Protocols.Spring.SpringBattleHostAsyncTest do
  use Teiserver.ServerCase, async: true

  # Seems flaky on CI, but can't reproduce locally
  # https://github.com/beyond-all-reason/teiserver/actions/runs/10629702218/job/29467089868
  @moduletag :needs_attention

  import Teiserver.TeiserverTestLib,
    only: [
      async_auth_setup: 0,
      _recv_lines: 0
    ]

  alias Teiserver.Client
  alias Teiserver.Protocols.SpringIn

  setup do
    %{user: user, state: state} = async_auth_setup()
    {:ok, state: state, user: user}
  end

  defp teardown(user) do
    Client.disconnect(user.id)
  end

  test "battle commands when not in a battle", %{state: state, user: user} do
    SpringIn.data_in("LEAVEBATTLE\n", state)
    reply = _recv_lines()
    assert reply == ""

    SpringIn.data_in("MYBATTLESTATUS 123 123\n", state)
    reply = _recv_lines()
    teardown(user)
    assert reply == ""
  end
end
