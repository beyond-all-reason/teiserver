defmodule Teiserver.Game.BalancerServerTest do
  @moduledoc false
  use Teiserver.DataCase, async: false

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

  test "load some players in and run a balance pass or two" do
    team_count = 2
    players = create_fake_players(4)

    {:ok, start_link_results} = BalancerServer.start_link(data: %{lobby_id: 1})

    starting_state = GenServer.call(start_link_results, :report_state, 5000)
    dbg(starting_state)

    dbg(players)

    first_balance_pass =
      GenServer.call(
        start_link_results,
        {:make_balance, team_count, [], players},
        5000
      )

    dbg(first_balance_pass)

    second_balance_pass_hash_reuse =
      GenServer.call(
        start_link_results,
        {:make_balance, team_count, [], create_fake_players(4)},
        5000
      )

    dbg(second_balance_pass_hash_reuse)

    assert second_balance_pass_hash_reuse.hash == first_balance_pass.hash

    third_balance_pass_with_more_players =
      GenServer.call(
        start_link_results,
        {:make_balance, team_count, [], create_fake_players(160)},
        5000
      )

    dbg(third_balance_pass_with_more_players)
    assert second_balance_pass_hash_reuse.hash != third_balance_pass_with_more_players.hash
  end

  defp create_fake_players(count) do
    1..count |> Enum.map(fn iter -> %{userid: iter, party_id: iter} end)
  end
end
