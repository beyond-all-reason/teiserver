defmodule Teiserver.MixTasks.PartyBalanceStatsTest do
  alias Mix.Tasks.Teiserver.PartyBalanceStats

  use ExUnit.Case

  test "check broken parties" do
    input = %{
      partied_players: [],
      team_players: %{1 => [42, 25, 21, 37, 40, 2], 2 => [39, 3, 32, 30, 41, 22]}
    }

    result = PartyBalanceStats.count_broken_parties(input)
    assert result == 0

    input = %{
      partied_players: [[42, 39]],
      team_players: %{1 => [42, 25, 21, 37, 40, 2], 2 => [39, 3, 32, 30, 41, 22]}
    }

    result = PartyBalanceStats.count_broken_parties(input)
    assert result == 1
  end

  test "solo balance" do
    team_count = 2

    players =
      PartyBalanceStats.make_solo_balance(
        team_count,
        players,
        rating_logs,
        opts
      )
  end
end
