defmodule Teiserver.Battle.BalanceLibTest do
  use Central.DataCase, async: true
  alias Teiserver.Battle.BalanceLib
  # alias Teiserver.TeiserverTestLib

  test "loser picks simple users" do
    result = BalanceLib.create_balance(
      [
        %{1 => 5},
        %{2 => 6},
        %{3 => 7},
        %{4 => 8},
      ],
      2,
      mode: :loser_picks
    )
    |> Map.drop([:logs])

    assert result == %{
      team_groups: %{
        1 => [
          {[4], %{count: 1, mean: 8.0, rating: 8, stddev: 0.0}},
          {[1], %{count: 1, mean: 5.0, rating: 5, stddev: 0.0}}],
        2 => [
          {[3], %{count: 1, mean: 7.0, rating: 7, stddev: 0.0}},
          {[2], %{count: 1, mean: 6.0, rating: 6, stddev: 0.0}}
        ]
      },
      team_players: %{
        1 => [4, 1],
        2 => [3, 2]
      },
      ratings: %{
        1 => 13,
        2 => 13
      },
      captains: %{
        1 => 4,
        2 => 3
      },
      team_sizes: %{
        1 => 2,
        2 => 2
      },
      deviation: 0
    }
  end

  test "loser picks simple group" do
    result = BalanceLib.create_balance(
      [
        %{4 => 5, 1 => 8},
        %{2 => 6},
        %{3 => 7}
      ],
      2,
      mode: :loser_picks
    )
    |> Map.drop([:logs])

    assert result == %{
      team_groups: %{
        1 => [
          {[1, 4], %{count: 2, mean: 6.5, rating: 13, stddev: 1.5}}
        ],
        2 => [
          {[3], %{count: 1, mean: 7.0, rating: 7, stddev: 0.0}},
          {[2], %{count: 1, mean: 6.0, rating: 6, stddev: 0.0}}
        ]
      },
      team_players: %{
        1 => [1, 4],
        2 => [3, 2]
      },
      ratings: %{
        1 => 13,
        2 => 13
      },
      captains: %{
        1 => 1,
        2 => 3
      },
      team_sizes: %{
        1 => 2,
        2 => 2
      },
      deviation: 0
    }
  end

  test "loser picks bigger game group" do
    result = BalanceLib.create_balance(
      [
        # Two high tier players partied together
        %{1 => 41, 2 => 35},

        # A bunch of mid-low tier players together
        %{3 => 20, 4 => 17, 5 => 13},

        # A smaller bunch of even lower tier players
        %{6 => 15, 7 => 9},

        # Other players, a range of ratings
        %{8 => 31},
        %{9 => 26},
        %{10 => 25},
        %{11 => 21},
        %{12 => 19},
        %{13 => 16},
        %{14 => 16},
        %{15 => 14},
        %{16 => 8}
      ],
      2,
      mode: :loser_picks
    )
    |> Map.drop([:logs])

    assert result == %{
      team_groups: %{
        1 => [
          {[1, 2], %{rating: 76, stddev: 3, mean: 38, count: 2}},
          {[9], %{rating: 26, stddev: 0, mean: 26, count: 1}},
          {[6, 7], %{rating: 24, stddev: 3, mean: 12, count: 2}},
          {[12], %{rating: 19, stddev: 0, mean: 19, count: 1}},
          {[15], %{rating: 14, stddev: 0, mean: 14, count: 1}},
          {[16], %{rating: 8, stddev: 0, mean: 8, count: 1}}
        ],
        2 => [
          {[3, 4, 5], %{rating: 50, stddev: 2.8674417556808756, mean: 16.666666666666668, count: 3}},
          {[8], %{rating: 31, stddev: 0, mean: 31, count: 1}},
          {[10], %{rating: 25, stddev: 0, mean: 25, count: 1}},
          {[11], %{rating: 21, stddev: 0, mean: 21, count: 1}},
          {[13], %{rating: 16, stddev: 0, mean: 16, count: 1}},
          {[14], %{rating: 16, stddev: 0, mean: 16, count: 1}}
        ]
      },
      team_players: %{
        1 => [1, 2, 9, 6, 7, 12, 15, 16],
        2 => [3, 4, 5, 8, 10, 11, 13, 14]
      },
      ratings: %{
        1 => 167,
        2 => 159
      },
      captains: %{
        1 => 1,
        2 => 3
      },
      team_sizes: %{
        1 => 8,
        2 => 8
      },
      deviation: 5
    }
  end
end
