defmodule Teiserver.Battle.BruteForceAvoidInternalTest do
  @moduledoc """
  Can run all balance tests via
  mix test --only balance_test
  """
  use ExUnit.Case
  @moduletag :balance_test
  alias Teiserver.Battle.Balance.BruteForceAvoid

  test "can get second team" do
    players = [
      %{name: "kyutoryu", rating: 12.25, id: 1},
      %{name: "fbots1998", rating: 13.98, id: 2},
      %{name: "Dixinormus", rating: 18.28, id: 3},
      %{name: "HungDaddy", rating: 2.8, id: 4},
      %{name: "SLOPPYGAGGER", rating: 8.89, id: 5},
      %{name: "jauggy", rating: 20.49, id: 6},
      %{name: "reddragon2010", rating: 18.4, id: 7},
      %{name: "Aposis", rating: 20.42, id: 8},
      %{name: "MaTThiuS_82", rating: 8.26, id: 9},
      %{name: "Noody", rating: 17.64, id: 10},
      %{name: "[DTG]BamBin0", rating: 20.06, id: 11},
      %{name: "barmalev", rating: 3.58, id: 12}
    ]

    first_team = [
      %{name: "kyutoryu", rating: 12.25, id: 1},
      %{name: "fbots1998", rating: 13.98, id: 2},
      %{name: "Dixinormus", rating: 18.28, id: 3},
      %{name: "HungDaddy", rating: 2.8, id: 4},
      %{name: "SLOPPYGAGGER", rating: 8.89, id: 5},
      %{name: "jauggy", rating: 20.49, id: 6}
    ]

    result = BruteForceAvoid.get_second_team(first_team, players)

    assert result == [
             %{id: 7, name: "reddragon2010", rating: 18.4},
             %{id: 8, name: "Aposis", rating: 20.42},
             %{id: 9, name: "MaTThiuS_82", rating: 8.26},
             %{id: 10, name: "Noody", rating: 17.64},
             %{id: 11, name: "[DTG]BamBin0", rating: 20.06},
             %{id: 12, name: "barmalev", rating: 3.58}
           ]
  end

  test "can get second team - side cases" do
    players = []

    first_team = []

    result = BruteForceAvoid.get_second_team(first_team, players)

    assert result == []

    players = [%{id: 7, name: "reddragon2010", rating: 18.4}]

    first_team = [%{id: 7, name: "reddragon2010", rating: 18.4}]

    result = BruteForceAvoid.get_second_team(first_team, players)

    assert result == []
  end

  test "can get captain rating" do
    first_team = [
      %{name: "kyutoryu", rating: 12.25, id: 1},
      %{name: "fbots1998", rating: 13.98, id: 2},
      %{name: "Dixinormus", rating: 18.28, id: 3},
      %{name: "HungDaddy", rating: 2.8, id: 4},
      %{name: "SLOPPYGAGGER", rating: 8.89, id: 5},
      %{name: "jauggy", rating: 20.49, id: 6}
    ]

    result = BruteForceAvoid.get_captain_rating(first_team)

    assert result == 20.49

    result = BruteForceAvoid.get_captain_rating([])

    assert result == 0
  end
end
