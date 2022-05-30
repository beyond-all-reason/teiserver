defmodule Teiserver.Battle.BalanceLibTest do
  use Central.DataCase, async: true
  alias Teiserver.Battle.BalanceLib

  @players_basic_4 [
      %{userid: 1, rank: 4},
      %{userid: 2, rank: 3},
      %{userid: 3, rank: 2},
      %{userid: 4, rank: 1}
    ]

  @players_complex_6 [
      %{userid: 1, rank: 10},
      %{userid: 2, rank: 8},
      %{userid: 3, rank: 8},
      %{userid: 4, rank: 4},
      %{userid: 5, rank: 4},
      %{userid: 6, rank: 1}
    ]

  @players_uneven_5 [
      %{userid: 1, rank: 8},
      %{userid: 2, rank: 4},
      %{userid: 3, rank: 4},
      %{userid: 4, rank: 4},
      %{userid: 5, rank: 4}
    ]

  test "round robin basic 4" do
    result = BalanceLib.balance_players(@players_basic_4, 2, :round_robin)

    team1 = result[1]
    team2 = result[2]

    assert Enum.count(team1) == 2
    assert Enum.count(team2) == 2

    assert BalanceLib.team_stats(team1) == {6, 3}
    assert BalanceLib.team_stats(team2) == {4, 2}

    assert BalanceLib.get_deviation(result) == 50
  end

  test "round robin complex 6" do
    result = BalanceLib.balance_players(@players_complex_6, 2, :round_robin)

    team1 = result[1]
    team2 = result[2]

    assert Enum.count(team1) == 3
    assert Enum.count(team2) == 3

    assert BalanceLib.team_stats(team1) == {22, 7.33}
    assert BalanceLib.team_stats(team2) == {13, 4.33}

    assert BalanceLib.get_deviation(result) == 69
  end

  test "loser picks basic 4" do
    result = BalanceLib.balance_players(@players_basic_4, 2, :loser_picks)

    team1 = result[1]
    team2 = result[2]

    assert Enum.count(team1) == 2
    assert Enum.count(team2) == 2

    assert BalanceLib.team_stats(team1) == {5, 2.5}
    assert BalanceLib.team_stats(team2) == {5, 2.5}

    assert BalanceLib.get_deviation(result) == 0
  end

  test "loser picks complex 6" do
    result = BalanceLib.balance_players(@players_complex_6, 2, :loser_picks)

    team1 = result[1]
    team2 = result[2]

    assert Enum.count(team1) == 3
    assert Enum.count(team2) == 3

    assert BalanceLib.team_stats(team1) == {18, 6}
    assert BalanceLib.team_stats(team2) == {17, 5.67}

    assert BalanceLib.get_deviation(result) == 6
  end

  test "loser picks uneven 5" do
    result = BalanceLib.balance_players(@players_uneven_5, 2, :loser_picks)

    team1 = result[1]
    team2 = result[2]

    assert Enum.count(team1) == 2
    assert Enum.count(team2) == 3

    assert BalanceLib.team_stats(team1) == {12, 6}
    assert BalanceLib.team_stats(team2) == {12, 4}

    assert BalanceLib.get_deviation(result) == 50
  end
end
