defmodule Teiserver.Game.BalancerServerTest do
  @moduledoc false
  use Teiserver.DataCase, async: true

  @moduletag :balance_test
  alias Teiserver.Game.BalancerServer

  test "get fuzz multiplier" do
    result = BalancerServer.get_fuzz_multiplier([])
    assert result == 0

    result = BalancerServer.get_fuzz_multiplier(algorithm: "loser_picks", fuzz_multiplier: 0.5)
    assert result == 0.5

    result = BalancerServer.get_fuzz_multiplier(algorithm: "split_noobs", fuzz_multiplier: 0.5)

    assert result == 0
  end

  test "calculate team size" do
    team_count = 2
    players = create_fake_players(1)
    result = BalancerServer.calculate_team_size(team_count, players)
    assert result == 1

    players = create_fake_players(2)
    result = BalancerServer.calculate_team_size(team_count, players)
    assert result == 1

    players = create_fake_players(6)
    assert Enum.count(players) == 6
    result = BalancerServer.calculate_team_size(team_count, players)
    assert result == 3

    players = create_fake_players(7)
    result = BalancerServer.calculate_team_size(team_count, players)
    assert result == 4
  end

  test "report empty state" do
    team_count = 2
    players = create_fake_players(4)
    _team_size = BalancerServer.calculate_team_size(team_count, players)

    {:ok, tharp} = BalancerServer.init(%{lobby_id: 1})
    dbg(tharp)

    {:ok, narp} = BalancerServer.start_link(data: tharp)
    dbg(narp)

    assert is_pid(narp)
    dbg(:sys.get_state(narp))

    report_state_result = GenServer.call(narp, :report_state)

    dbg(report_state_result)
  end

  defp create_fake_players(count) do
    1..count |> Enum.map(fn _ -> %{} end)
  end
end
