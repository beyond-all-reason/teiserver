defmodule Teiserver.Battle.LoserPicksBalanceTest do
  @moduledoc """
  Can run all balance tests via
  mix test --only balance_test
  """
  use Teiserver.DataCase, async: true
  @moduletag :balance_test
  alias Teiserver.Battle.BalanceLib

  @algorithm "loser_picks"

  test "simple users" do
    result =
      BalanceLib.create_balance(
        [
          %{1 => %{rating: 5}},
          %{2 => %{rating: 6}},
          %{3 => %{rating: 7}},
          %{4 => %{rating: 8}}
        ],
        2,
        algorithm: @algorithm
      )
      |> Map.drop([:logs, :time_taken])

    assert result == %{
             team_groups: %{
               1 => [
                 %{members: [4], count: 1, group_rating: 8, ratings: [8]},
                 %{members: [1], count: 1, group_rating: 5, ratings: [5]}
               ],
               2 => [
                 %{members: [3], count: 1, group_rating: 7, ratings: [7]},
                 %{members: [2], count: 1, group_rating: 6, ratings: [6]}
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
             deviation: 0,
             means: %{1 => 6.5, 2 => 6.5},
             stdevs: %{1 => 1.5, 2 => 0.5},
             has_parties?: false
           }
  end

  test "ffa" do
    result =
      BalanceLib.create_balance(
        [
          %{1 => %{rating: 5}},
          %{2 => %{rating: 6}},
          %{3 => %{rating: 7}},
          %{4 => %{rating: 8}}
        ],
        4,
        algorithm: @algorithm
      )
      |> Map.drop([:logs, :time_taken])

    assert result == %{
             team_groups: %{
               1 => [%{members: [4], count: 1, group_rating: 8, ratings: [8]}],
               2 => [%{count: 1, group_rating: 7, members: [3], ratings: [7]}],
               3 => [%{count: 1, group_rating: 6, members: [2], ratings: [6]}],
               4 => [%{count: 1, group_rating: 5, members: [1], ratings: [5]}]
             },
             team_players: %{
               1 => [4],
               2 => [3],
               3 => [2],
               4 => [1]
             },
             ratings: %{
               1 => 8,
               2 => 7,
               3 => 6,
               4 => 5
             },
             captains: %{
               1 => 4,
               2 => 3,
               3 => 2,
               4 => 1
             },
             team_sizes: %{
               1 => 1,
               2 => 1,
               3 => 1,
               4 => 1
             },
             deviation: 13,
             means: %{1 => 8.0, 2 => 7.0, 3 => 6.0, 4 => 5.0},
             stdevs: %{1 => 0.0, 2 => 0.0, 3 => 0.0, 4 => 0.0},
             has_parties?: false
           }
  end

  test "team ffa" do
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
        algorithm: @algorithm
      )
      |> Map.drop([:logs, :time_taken])

    assert result == %{
             team_groups: %{
               1 => [
                 %{count: 1, group_rating: 9, members: [5], ratings: [9]},
                 %{count: 1, group_rating: 6, members: [2], ratings: [6]}
               ],
               2 => [
                 %{count: 1, group_rating: 9, members: [6], ratings: [9]},
                 %{count: 1, group_rating: 5, members: [1], ratings: [5]}
               ],
               3 => [
                 %{count: 1, group_rating: 8, members: [4], ratings: [8]},
                 %{count: 1, group_rating: 7, members: [3], ratings: [7]}
               ]
             },
             team_players: %{
               1 => [5, 2],
               2 => [6, 1],
               3 => [4, 3]
             },
             ratings: %{
               1 => 15,
               2 => 14,
               3 => 15
             },
             captains: %{
               1 => 5,
               2 => 6,
               3 => 4
             },
             team_sizes: %{
               1 => 2,
               2 => 2,
               3 => 2
             },
             deviation: 0,
             means: %{1 => 7.5, 2 => 7.0, 3 => 7.5},
             stdevs: %{1 => 1.5, 2 => 2.0, 3 => 0.5},
             has_parties?: false
           }
  end

  test "simple group" do
    result =
      BalanceLib.create_balance(
        [
          %{4 => %{rating: 5}, 1 => %{rating: 8}},
          %{2 => %{rating: 6}},
          %{3 => %{rating: 7}}
        ],
        2,
        algorithm: @algorithm,
        rating_lower_boundary: 100,
        rating_upper_boundary: 100,
        mean_diff_max: 100,
        stddev_diff_max: 100
      )
      |> Map.drop([:logs, :time_taken])

    assert result == %{
             team_groups: %{
               1 => [
                 %{count: 2, group_rating: 13, members: [1, 4], ratings: [8, 5]}
               ],
               2 => [
                 %{count: 2, group_rating: 13, members: [2, 3], ratings: [6, 7]}
               ]
             },
             team_players: %{
               1 => [1, 4],
               2 => [2, 3]
             },
             ratings: %{
               1 => 13,
               2 => 13
             },
             # The captain should be the user with the highest rating on each team
             captains: %{
               1 => 1,
               2 => 3
             },
             team_sizes: %{
               1 => 2,
               2 => 2
             },
             deviation: 0,
             means: %{1 => 6.5, 2 => 6.5},
             stdevs: %{1 => 1.5, 2 => 0.5},
             has_parties?: true
           }
  end

  test "bigger game group" do
    result =
      BalanceLib.create_balance(
        [
          # Two high tier players partied together
          %{101 => %{rating: 41}, 102 => %{rating: 35}},

          # A bunch of mid-low tier players together
          %{103 => %{rating: 20}, 104 => %{rating: 17}, 105 => %{rating: 13.5}},

          # A smaller bunch of even lower tier players
          %{106 => %{rating: 15}, 107 => %{rating: 7.5}},

          # Other players, a range of ratings
          %{108 => %{rating: 31}},
          %{109 => %{rating: 26}},
          %{110 => %{rating: 25}},
          %{111 => %{rating: 21}},
          %{112 => %{rating: 19}},
          %{113 => %{rating: 16}},
          %{114 => %{rating: 16}},
          %{115 => %{rating: 14}},
          %{116 => %{rating: 8}}
        ],
        2,
        algorithm: @algorithm,
        rating_lower_boundary: 5,
        rating_upper_boundary: 5,
        mean_diff_max: 5,
        stddev_diff_max: 5
      )

    assert Map.drop(result, [:logs, :time_taken]) == %{
             captains: %{1 => 101, 2 => 102},
             deviation: 2,
             ratings: %{1 => 161, 2 => 164},
             team_groups: %{
               1 => [
                 %{count: 3, group_rating: 51, members: [112, 113, 114], ratings: [19, 16, 16]},
                 %{count: 2, group_rating: 22, members: [115, 116], ratings: [14, 8]},
                 %{count: 1, group_rating: 41, members: [101], ratings: [41]},
                 %{count: 1, group_rating: 26, members: [109], ratings: [26]},
                 %{count: 1, group_rating: 21, members: [111], ratings: [21]}
               ],
               2 => [
                 %{
                   count: 3,
                   group_rating: 50.5,
                   members: [103, 104, 105],
                   ratings: [20, 17, 13.5]
                 },
                 %{count: 2, group_rating: 22.5, members: [106, 107], ratings: [15, 7.5]},
                 %{count: 1, group_rating: 35, members: [102], ratings: [35]},
                 %{count: 1, group_rating: 31, members: [108], ratings: [31]},
                 %{count: 1, group_rating: 25, members: [110], ratings: [25]}
               ]
             },
             team_players: %{
               1 => [112, 113, 114, 115, 116, 101, 109, 111],
               2 => [103, 104, 105, 106, 107, 102, 108, 110]
             },
             team_sizes: %{1 => 8, 2 => 8},
             means: %{1 => 20.125, 2 => 20.5},
             stdevs: %{1 => 9.29297449689818, 2 => 8.671072598012312},
             has_parties?: true
           }
  end

  test "smurf party" do
    result =
      BalanceLib.create_balance(
        [
          # Our smurf party
          %{101 => %{rating: 51}, 102 => %{rating: 10}, 103 => %{rating: 10}},

          # Other players, a range of ratings
          %{104 => %{rating: 35}},
          %{105 => %{rating: 34}},
          %{106 => %{rating: 29}},
          %{107 => %{rating: 28}},
          %{108 => %{rating: 27}},
          %{109 => %{rating: 26}},
          %{110 => %{rating: 25}},
          %{111 => %{rating: 21}},
          %{112 => %{rating: 19}},
          %{113 => %{rating: 16}},
          %{114 => %{rating: 15}},
          %{115 => %{rating: 14}},
          %{116 => %{rating: 8}}
        ],
        2,
        algorithm: @algorithm
      )

    assert Map.drop(result, [:logs, :time_taken]) == %{
             captains: %{1 => 101, 2 => 104},
             deviation: 0,
             ratings: %{1 => 184, 2 => 184},
             team_groups: %{
               1 => [
                 %{count: 1, group_rating: 51, members: [101], ratings: [51]},
                 %{count: 1, group_rating: 29, members: [106], ratings: [29]},
                 %{count: 1, group_rating: 27, members: [108], ratings: [27]},
                 %{count: 1, group_rating: 25, members: [110], ratings: [25]},
                 %{count: 1, group_rating: 19, members: [112], ratings: [19]},
                 %{count: 1, group_rating: 15, members: [114], ratings: [15]},
                 %{count: 1, group_rating: 10, members: [102], ratings: [10]},
                 %{count: 1, group_rating: 8, members: [116], ratings: [8]}
               ],
               2 => [
                 %{count: 1, group_rating: 35, members: [104], ratings: ~c"#"},
                 %{count: 1, group_rating: 34, members: [105], ratings: [34]},
                 %{count: 1, group_rating: 28, members: [107], ratings: [28]},
                 %{count: 1, group_rating: 26, members: [109], ratings: [26]},
                 %{count: 1, group_rating: 21, members: [111], ratings: [21]},
                 %{count: 1, group_rating: 16, members: [113], ratings: [16]},
                 %{count: 1, group_rating: 14, members: [115], ratings: [14]},
                 %{count: 1, group_rating: 10, members: [103], ratings: ~c"\n"}
               ]
             },
             team_players: %{1 => ~c"ejlnprft", 2 => ~c"hikmoqsg"},
             team_sizes: %{1 => 8, 2 => 8},
             means: %{1 => 23.0, 2 => 23.0},
             stdevs: %{1 => 12.816005617976296, 2 => 8.674675786448736},
             has_parties?: false
           }
  end

  test "two parties" do
    result =
      BalanceLib.create_balance(
        [
          # Our high tier party
          %{101 => %{rating: 52}, 102 => %{rating: 50}, 103 => %{rating: 49}},

          # Our other high tier party
          %{104 => %{rating: 51}, 105 => %{rating: 50}, 106 => %{rating: 50}},

          # Other players, a range of ratings
          %{107 => %{rating: 28}},
          %{108 => %{rating: 27}},
          %{109 => %{rating: 26}},
          %{110 => %{rating: 25}},
          %{111 => %{rating: 21}},
          %{112 => %{rating: 19}},
          %{113 => %{rating: 16}},
          %{114 => %{rating: 15}},
          %{115 => %{rating: 14}},
          %{116 => %{rating: 8}}
        ],
        2,
        algorithm: @algorithm
      )

    assert Map.drop(result, [:logs, :time_taken]) == %{
             # The captain should be the user with the highest rating on each team
             captains: %{1 => 104, 2 => 101},
             deviation: 2,
             ratings: %{1 => 248, 2 => 253},
             team_groups: %{
               1 => [
                 %{count: 3, group_rating: 151, members: [104, 105, 106], ratings: [51, 50, 50]},
                 %{count: 1, group_rating: 28, members: [107], ratings: [28]},
                 %{count: 1, group_rating: 25, members: [110], ratings: [25]},
                 %{count: 1, group_rating: 21, members: [111], ratings: [21]},
                 %{count: 1, group_rating: 15, members: [114], ratings: [15]},
                 %{count: 1, group_rating: 8, members: [116], ratings: [8]}
               ],
               2 => [
                 %{count: 3, group_rating: 151, members: [101, 102, 103], ratings: [52, 50, 49]},
                 %{count: 1, group_rating: 27, members: [108], ratings: [27]},
                 %{count: 1, group_rating: 26, members: [109], ratings: [26]},
                 %{count: 1, group_rating: 19, members: [112], ratings: [19]},
                 %{count: 1, group_rating: 16, members: [113], ratings: [16]},
                 %{count: 1, group_rating: 14, members: [115], ratings: [14]}
               ]
             },
             team_players: %{
               1 => [104, 105, 106, 107, 110, 111, 114, 116],
               2 => [101, 102, 103, 108, 109, 112, 113, 115]
             },
             team_sizes: %{1 => 8, 2 => 8},
             means: %{1 => 31.0, 2 => 31.625},
             stdevs: %{1 => 16.015617378046965, 2 => 15.090870584562046},
             has_parties?: true
           }

    result2 =
      BalanceLib.create_balance(
        [
          # Our high tier party
          %{101 => %{rating: 52}, 102 => %{rating: 50}, 103 => %{rating: 49}},

          # Our other high tier party, only 2 people this time
          %{104 => %{rating: 51}, 105 => %{rating: 50}},

          # Other players, a range of ratings
          %{106 => %{rating: 50}},
          %{107 => %{rating: 28}},
          %{108 => %{rating: 27}},
          %{109 => %{rating: 26}},
          %{110 => %{rating: 25}},
          %{111 => %{rating: 21}},
          %{112 => %{rating: 19}},
          %{113 => %{rating: 16}},
          %{114 => %{rating: 15}},
          %{115 => %{rating: 14}},
          %{116 => %{rating: 8}}
        ],
        2,
        algorithm: @algorithm
      )

    # This is very similar to the previous one but a few things about the exact
    # pick order is different
    assert Map.drop(result2, [:logs, :time_taken]) == %{
             captains: %{1 => 101, 2 => 104},
             deviation: 2,
             ratings: %{1 => 248, 2 => 253},
             team_groups: %{
               1 => [
                 %{count: 3, group_rating: 151, members: [101, 102, 103], ratings: [52, 50, 49]},
                 %{count: 1, group_rating: 28, members: [107], ratings: [28]},
                 %{count: 1, group_rating: 25, members: [110], ratings: [25]},
                 %{count: 1, group_rating: 21, members: [111], ratings: [21]},
                 %{count: 1, group_rating: 15, members: [114], ratings: [15]},
                 %{count: 1, group_rating: 8, members: [116], ratings: [8]}
               ],
               2 => [
                 %{count: 3, group_rating: 151, members: [106, 104, 105], ratings: [50, 51, 50]},
                 %{count: 1, group_rating: 27, members: [108], ratings: [27]},
                 %{count: 1, group_rating: 26, members: [109], ratings: [26]},
                 %{count: 1, group_rating: 19, members: [112], ratings: [19]},
                 %{count: 1, group_rating: 16, members: [113], ratings: [16]},
                 %{count: 1, group_rating: 14, members: [115], ratings: [14]}
               ]
             },
             team_players: %{
               1 => [101, 102, 103, 107, 110, 111, 114, 116],
               2 => [106, 104, 105, 108, 109, 112, 113, 115]
             },
             team_sizes: %{1 => 8, 2 => 8},
             means: %{1 => 31.0, 2 => 31.625},
             stdevs: %{1 => 16.0312195418814, 2 => 15.074295174236173},
             has_parties?: true
           }
  end
end
