defmodule Teiserver.Battle.SplitOneChevsTest do
  @moduledoc """
  Can run tests in this file only by
  mix test test/teiserver/battle/split_one_chevs_test.exs
  """
  use Teiserver.DataCase, async: true
  @moduletag :balance_test
  alias Teiserver.Battle.BalanceLib

  # Define constants
  @split_algo "split_one_chevs"

  test "split one chevs empty" do
    result =
      BalanceLib.create_balance(
        [],
        4,
        algorithm: @split_algo
      )

    assert result == %{
             logs: [],
             ratings: %{},
             time_taken: 0,
             captains: %{},
             deviation: 0,
             team_groups: %{},
             team_players: %{},
             team_sizes: %{},
             means: %{},
             stdevs: %{}
           }
  end

  test "split one chevs FFA" do
    result =
      BalanceLib.create_balance(
        [
          %{1 => %{rating: 5}},
          %{2 => %{rating: 6}},
          %{3 => %{rating: 7}},
          %{4 => %{rating: 8}}
        ],
        4,
        algorithm: @split_algo
      )

    assert result.team_players == %{1 => [4], 2 => [3], 3 => [2], 4 => [1]}
  end

  test "split one chevs team FFA" do
    result =
      BalanceLib.create_balance(
        [
          %{1 => %{rating: 5}},
          %{2 => %{rating: 6}},
          %{3 => %{rating: 7}},
          %{4 => %{rating: 8}},
          %{5 => %{rating: 9}},
          %{6 => %{rating: 9}}
        ],
        3,
        algorithm: @split_algo
      )

    assert result.team_players == %{1 => [1, 5], 2 => [2, 6], 3 => [3, 4]}
  end

  test "split one chevs simple group" do
    result =
      BalanceLib.create_balance(
        [
          %{4 => %{rating: 5}, 1 => %{rating: 8}},
          %{2 => %{rating: 6}},
          %{3 => %{rating: 7}}
        ],
        2,
        rating_lower_boundary: 100,
        rating_upper_boundary: 100,
        mean_diff_max: 100,
        stddev_diff_max: 100,
        algorithm: @split_algo
      )

    assert result.team_players == %{1 => [4, 1], 2 => [2, 3]}
  end


  test "logs FFA" do
    result =
      BalanceLib.create_balance(
        [
          %{"Pro1" => %{rating: 5, rank: 1}},
          %{"Pro2" => %{rating: 6, rank: 1}},
          %{"Noob1" => %{rating: 7, rank: 0}},
          %{"Noob2" => %{rating: 8, rank: 0}}
        ],
        4,
        algorithm: @split_algo
      )

    assert result.logs == [
             "Begin split_one_chevs balance",
             "Pro2 (Chev: 2) picked for Team 1",
             "Pro1 (Chev: 2) picked for Team 2",
             "Noob2 (Chev: 1) picked for Team 3",
             "Noob1 (Chev: 1) picked for Team 4"
           ]
  end

  test "logs Team" do
    result =
      BalanceLib.create_balance(
        [
          %{"Pro1" => %{rating: 5, rank: 1}},
          %{"Pro2" => %{rating: 6, rank: 1}},
          %{"Noob1" => %{rating: 7, rank: 0}},
          %{"Noob2" => %{rating: 8, rank: 0}}
        ],
        2,
        algorithm: @split_algo
      )

    assert result.logs == [
             "Begin split_one_chevs balance",
             "Pro2 (Chev: 2) picked for Team 1",
             "Pro1 (Chev: 2) picked for Team 2",
             "Noob2 (Chev: 1) picked for Team 2",
             "Noob1 (Chev: 1) picked for Team 1"
           ]
  end
end
