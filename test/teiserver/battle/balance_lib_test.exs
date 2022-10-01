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
        %{101 => 41, 102 => 35},

        # A bunch of mid-low tier players together
        %{103 => 20, 104 => 17, 105 => 13.5},

        # A smaller bunch of even lower tier players
        %{106 => 15, 107 => 7.5},

        # Other players, a range of ratings
        %{108 => 31},
        %{109 => 26},
        %{110 => 25},
        %{111 => 21},
        %{112 => 19},
        %{113 => 16},
        %{114 => 16},
        %{115 => 14},
        %{116 => 8}
      ],
      2,
      mode: :loser_picks
    )

    IO.puts result.logs |> Enum.join("\n")

    assert Map.drop(result, [:logs]) == %{
      team_groups: %{
        1 => [
          %{members: [1, 2], group_rating: 76, ratings: [41, 35], count: 2},
          %{members: [9], group_rating: 26, ratings: [26], count: 1},
          %{members: [6, 7], group_rating: 24, ratings: [15, 9], count: 2},
          %{members: [12], group_rating: 19, ratings: [19], count: 1},
          %{members: [15], group_rating: 14, ratings: [14], count: 1},
          %{members: [16], group_rating: 8, ratings: [8], count: 1}
        ],
        2 => [
          %{members: [3, 4, 5], group_rating: 50, ratings: [20, 17, 13], count: 3},
          %{members: [8], group_rating: 31, ratings: [31], count: 1},
          %{members: [10], group_rating: 25, ratings: [25], count: 1},
          %{members: [11], group_rating: 21, ratings: [21], count: 1},
          %{members: [13], group_rating: 16, ratings: [16], count: 1},
          %{members: [14], group_rating: 16, ratings: [16], count: 1}
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
