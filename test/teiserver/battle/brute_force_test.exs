defmodule Teiserver.Battle.BruteForceTest do
  @moduledoc """
  Can run all balance tests via
  mix test --only balance_test
  """
  use Teiserver.DataCase, async: true
  @moduletag :balance_test
  alias Teiserver.Battle.Balance.BruteForce

  test "can process expanded_group" do
    # https://server5.beyondallreason.info/battle/2092529/players
    expanded_group = [
      %{
        count: 2,
        members: ["kyutoryu", "fbots1998"],
        ratings: [12.25, 13.98],
        names: ["kyutoryu", "fbots1998"],
        uncertainties: [0, 1],
        ranks: [1, 1]
      },
      %{
        count: 1,
        members: ["Dixinormus"],
        ratings: [18.28],
        names: ["Dixinormus"],
        uncertainties: [2, 1],
        ranks: [2]
      },
      %{
        count: 1,
        members: ["HungDaddy"],
        ratings: [2.8],
        names: ["HungDaddy"],
        uncertainties: [2, 1],
        ranks: [2]
      },
      %{
        count: 1,
        members: ["SLOPPYGAGGER"],
        ratings: [8.89],
        names: ["SLOPPYGAGGER"],
        uncertainties: [3],
        ranks: [2]
      },
      %{
        count: 1,
        members: ["jauggy"],
        ratings: [20.49],
        names: ["jauggy"],
        uncertainties: [3],
        ranks: [2]
      },
      %{
        count: 1,
        members: ["reddragon2010"],
        ratings: [18.4],
        names: ["reddragon2010"],
        uncertainties: [3],
        ranks: [2]
      },
      %{
        count: 1,
        members: ["Aposis"],
        ratings: [20.42],
        names: ["Aposis"],
        uncertainties: [3],
        ranks: [2]
      },
      %{
        count: 1,
        members: ["MaTThiuS_82"],
        ratings: [8.26],
        names: ["MaTThiuS_82"],
        uncertainties: [3],
        ranks: [2]
      },
      %{
        count: 1,
        members: ["Noody"],
        ratings: [17.64],
        names: ["Noody"],
        uncertainties: [3],
        ranks: [2]
      },
      %{
        count: 1,
        members: ["[DTG]BamBin0"],
        ratings: [20.06],
        names: ["[DTG]BamBin0"],
        uncertainties: [3],
        ranks: [2]
      },
      %{
        count: 1,
        members: ["barmalev"],
        ratings: [3.58],
        names: ["barmalev"],
        uncertainties: [3],
        ranks: [2]
      }
    ]

    result = BruteForce.perform(expanded_group, 2) |> Map.drop([:logs])

    assert result == %{
             team_groups: %{
               1 => [
                 %{count: 1, group_rating: 12.25, members: ["kyutoryu"], ratings: [12.25]},
                 %{count: 1, group_rating: 13.98, members: ["fbots1998"], ratings: [13.98]},
                 %{count: 1, group_rating: 8.89, members: ["SLOPPYGAGGER"], ratings: [8.89]},
                 %{count: 1, group_rating: 20.49, members: ["jauggy"], ratings: [20.49]},
                 %{count: 1, group_rating: 18.4, members: ["reddragon2010"], ratings: [18.4]},
                 %{count: 1, group_rating: 8.26, members: ["MaTThiuS_82"], ratings: [8.26]}
               ],
               2 => [
                 %{count: 1, group_rating: 18.28, members: ["Dixinormus"], ratings: [18.28]},
                 %{count: 1, group_rating: 2.8, members: ["HungDaddy"], ratings: [2.8]},
                 %{count: 1, group_rating: 20.42, members: ["Aposis"], ratings: [20.42]},
                 %{count: 1, group_rating: 17.64, members: ["Noody"], ratings: [17.64]},
                 %{count: 1, group_rating: 20.06, members: ["[DTG]BamBin0"], ratings: [20.06]},
                 %{count: 1, group_rating: 3.58, members: ["barmalev"], ratings: [3.58]}
               ]
             },
             team_players: %{
               1 => [
                 "kyutoryu",
                 "fbots1998",
                 "SLOPPYGAGGER",
                 "jauggy",
                 "reddragon2010",
                 "MaTThiuS_82"
               ],
               2 => ["Dixinormus", "HungDaddy", "Aposis", "Noody", "[DTG]BamBin0", "barmalev"]
             }
           }
  end

  test "can keep parties together" do
    # https://server5.beyondallreason.info/battle/3060507/players
    expanded_group = [
      %{
        count: 4,
        members: ["A", "B", "C", "D"],
        ratings: [23.37, 28.2, 16.14, 32.23],
        names: ["A", "B", "C", "D"],
        uncertainties: [0, 1, 0, 0],
        ranks: [2, 2, 2, 2]
      },
      %{
        count: 2,
        members: ["E", "F"],
        ratings: [23, 28.32],
        names: ["E", "F"],
        uncertainties: [2, 1],
        ranks: [2, 2]
      },
      %{
        count: 1,
        members: ["GrandMasterK311"],
        ratings: [4.5],
        names: ["GrandMasterK311"],
        uncertainties: [2],
        ranks: [2]
      },
      %{
        count: 1,
        members: ["MacDi"],
        ratings: [13.08],
        names: ["MacDi"],
        uncertainties: [3],
        ranks: [2]
      },
      %{
        count: 1,
        members: ["Mr_Dirac"],
        ratings: [35.62],
        names: ["Mr_Dirac"],
        uncertainties: [3],
        ranks: [2]
      },
      %{
        count: 1,
        members: ["earrebarre"],
        ratings: [18.4],
        names: ["earrebarre"],
        uncertainties: [14.12],
        ranks: [2]
      }
    ]

    result = BruteForce.perform(expanded_group, 2)

    assert result == %{
             logs: [
               "Algorithm: brute_force",
               "------------------------------------------------------",
               "Parties: [A, B, C, D], [E, F]",
               "Team rating diff penalty: 3.2",
               "Broken party penalty: 0",
               "Score: 3.2 (lower is better)",
               "Team 1: A, B, C, D, MacDi",
               "Team 2: E, F, GrandMasterK311, Mr_Dirac, earrebarre"
             ],
             team_groups: %{
               1 => [
                 %{count: 1, group_rating: 23.37, members: ["A"], ratings: [23.37]},
                 %{count: 1, group_rating: 28.2, members: ["B"], ratings: [28.2]},
                 %{count: 1, group_rating: 16.14, members: ["C"], ratings: [16.14]},
                 %{count: 1, group_rating: 32.23, members: ["D"], ratings: [32.23]},
                 %{count: 1, group_rating: 13.08, members: ["MacDi"], ratings: [13.08]}
               ],
               2 => [
                 %{count: 1, group_rating: 23, members: ["E"], ratings: [23]},
                 %{count: 1, group_rating: 28.32, members: ["F"], ratings: [28.32]},
                 %{count: 1, group_rating: 4.5, members: ["GrandMasterK311"], ratings: [4.5]},
                 %{count: 1, group_rating: 35.62, members: ["Mr_Dirac"], ratings: [35.62]},
                 %{count: 1, group_rating: 18.4, members: ["earrebarre"], ratings: [18.4]}
               ]
             },
             team_players: %{
               1 => ["A", "B", "C", "D", "MacDi"],
               2 => ["E", "F", "GrandMasterK311", "Mr_Dirac", "earrebarre"]
             }
           }
  end
end
