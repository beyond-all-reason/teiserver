defmodule Teiserver.Battle.SplitOneChevsTest do
  @moduledoc """
  Can run all balance tests via
  mix test --only balance_test
  """
  use ExUnit.Case
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
             stdevs: %{},
             has_parties?: false
           }
  end

  test "split one chevs FFA" do
    result =
      BalanceLib.create_balance(
        [
          %{1 => %{rating: 5, rank: 2}},
          %{2 => %{rating: 6, rank: 2}},
          %{3 => %{rating: 7, rank: 2}},
          %{4 => %{rating: 8, rank: 2}}
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
          %{1 => %{rating: 5, rank: 2}},
          %{2 => %{rating: 6, rank: 2}},
          %{3 => %{rating: 7, rank: 2}},
          %{4 => %{rating: 8, rank: 2}},
          %{5 => %{rating: 9, rank: 2}},
          %{6 => %{rating: 9, rank: 2}}
        ],
        3,
        algorithm: @split_algo
      )

    assert result.team_players == %{1 => [5, 2], 2 => [6, 1], 3 => [4, 3]}
  end

  test "split one chevs simple group" do
    result =
      BalanceLib.create_balance(
        [
          %{4 => %{rating: 5, rank: 2}, 1 => %{rating: 8, rank: 2}},
          %{2 => %{rating: 6, rank: 2}},
          %{3 => %{rating: 7, rank: 2}}
        ],
        2,
        rating_lower_boundary: 100,
        rating_upper_boundary: 100,
        mean_diff_max: 100,
        stddev_diff_max: 100,
        algorithm: @split_algo
      )

    assert result.team_players == %{1 => [1, 4], 2 => [2, 3]}
  end

  test "logs FFA" do
    result =
      BalanceLib.create_balance(
        [
          %{"Pro1" => %{rating: 5, rank: 2}},
          %{"Pro2" => %{rating: 6, rank: 2}},
          %{"Noob1" => %{rating: 7, rank: 1, uncertainty: 7}},
          %{"Noob2" => %{rating: 8, rank: 0, uncertainty: 8}}
        ],
        4,
        algorithm: @split_algo
      )

    assert result.logs == [
             "Algorithm: split_one_chevs",
             "---------------------------",
             "Your team will try and pick 3Chev+ players first, with preference for higher OS. If 1-2Chevs are the only remaining players, then lower uncertainty is preferred.",
             "---------------------------",
             "Pro2 (6, σ: 0, Chev: 3) picked for Team 1",
             "Pro1 (5, σ: 0, Chev: 3) picked for Team 2",
             "Noob1 (7, σ: 7, Chev: 2) picked for Team 3",
             "Noob2 (8, σ: 8, Chev: 1) picked for Team 4"
           ]
  end

  test "logs Team" do
    result =
      BalanceLib.create_balance(
        [
          %{"Pro1" => %{rating: 5, rank: 2}},
          %{"Pro2" => %{rating: 6, rank: 2}},
          %{"Noob1" => %{rating: 7, rank: 0, uncertainty: 7.9}},
          %{"Noob2" => %{rating: 8, rank: 0, uncertainty: 8}}
        ],
        2,
        algorithm: @split_algo
      )

    assert result.logs == [
             "Algorithm: split_one_chevs",
             "---------------------------",
             "Your team will try and pick 3Chev+ players first, with preference for higher OS. If 1-2Chevs are the only remaining players, then lower uncertainty is preferred.",
             "---------------------------",
             "Pro2 (6, σ: 0, Chev: 3) picked for Team 1",
             "Pro1 (5, σ: 0, Chev: 3) picked for Team 2",
             "Noob1 (7, σ: 7.9, Chev: 1) picked for Team 2",
             "Noob2 (8, σ: 8, Chev: 1) picked for Team 1"
           ]
  end

  test "calls another balancer when no noobs" do
    result =
      BalanceLib.create_balance(
        [
          %{"A" => %{rating: 5, rank: 2}},
          %{"B" => %{rating: 6, rank: 2}},
          %{"C" => %{rating: 7, rank: 2, uncertainty: 7.9}},
          %{"D" => %{rating: 8, rank: 2, uncertainty: 8}}
        ],
        2,
        algorithm: @split_algo
      )

    assert result.logs == [
             "Not enough noobs; calling another balancer.",
             "---------------------------",
             "Picked D for team 1, adding 8.0 points for new total of 8.0",
             "Picked C for team 2, adding 7.0 points for new total of 7.0",
             "Picked B for team 2, adding 6.0 points for new total of 13.0",
             "Picked A for team 1, adding 5.0 points for new total of 13.0"
           ]
  end
end
