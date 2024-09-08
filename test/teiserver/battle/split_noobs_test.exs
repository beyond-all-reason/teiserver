defmodule Teiserver.Battle.SplitNoobsTest do
  @moduledoc """
  Can run all balance tests via
  mix test --only balance_test
  """
  use ExUnit.Case
  @moduletag :balance_test
  alias Teiserver.Battle.Balance.SplitNoobs

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
        uncertainties: [2],
        ranks: [0]
      },
      %{
        count: 1,
        members: ["HungDaddy"],
        ratings: [2.8],
        names: ["HungDaddy"],
        uncertainties: [2],
        ranks: [0]
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

    result = SplitNoobs.perform(expanded_group, 2) |> Map.drop([:logs])

    assert result == %{
             team_groups: %{
               1 => [
                 %{count: 1, group_rating: 13.98, members: ["fbots1998"], ratings: [13.98]},
                 %{count: 1, group_rating: 12.25, members: ["kyutoryu"], ratings: [12.25]},
                 %{count: 1, group_rating: 20.49, members: ["jauggy"], ratings: [20.49]},
                 %{count: 1, group_rating: 18.4, members: ["reddragon2010"], ratings: [18.4]},
                 %{count: 1, group_rating: 8.89, members: ["SLOPPYGAGGER"], ratings: [8.89]},
                 %{count: 1, group_rating: 8.26, members: ["MaTThiuS_82"], ratings: [8.26]}
               ],
               2 => [
                 %{count: 1, group_rating: 20.42, members: ["Aposis"], ratings: [20.42]},
                 %{count: 1, group_rating: 20.06, members: ["[DTG]BamBin0"], ratings: [20.06]},
                 %{count: 1, group_rating: 18.28, members: ["Dixinormus"], ratings: [18.28]},
                 %{count: 1, group_rating: 17.64, members: ["Noody"], ratings: [17.64]},
                 %{count: 1, group_rating: 3.58, members: ["barmalev"], ratings: [3.58]},
                 %{count: 1, group_rating: 2.8, members: ["HungDaddy"], ratings: [2.8]}
               ]
             },
             team_players: %{
               1 => [
                 "fbots1998",
                 "kyutoryu",
                 "jauggy",
                 "reddragon2010",
                 "SLOPPYGAGGER",
                 "MaTThiuS_82"
               ],
               2 => ["Aposis", "[DTG]BamBin0", "Dixinormus", "Noody", "barmalev", "HungDaddy"]
             }
           }
  end

  test "can process expanded_group with no parties" do
    expanded_group = [
      %{
        count: 1,
        members: ["kyutoryu"],
        ratings: [12.25],
        names: ["kyutoryu"],
        uncertainties: [7.1],
        ranks: [1]
      },
      %{
        count: 1,
        members: ["Dixinormus"],
        ratings: [18.28],
        names: ["Dixinormus"],
        uncertainties: [2],
        ranks: [0]
      },
      %{
        count: 1,
        members: ["HungDaddy"],
        ratings: [0],
        names: ["HungDaddy"],
        uncertainties: [2],
        ranks: [0]
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
      }
    ]

    result = SplitNoobs.perform(expanded_group, 2)

    assert result == %{
             logs: [
               "------------------------------------------------------",
               "Algorithm: split_noobs",
               "------------------------------------------------------",
               "This algorithm will evenly distribute noobs and devalue them. Noobs are non-partied players that have either high uncertainty or 0 rating. Noobs will always be drafted last. For non-noobs, teams will prefer higher rating. For noobs, teams will prefer higher chevrons and lower uncertainty.",
               "------------------------------------------------------",
               "Parties: None",
               "Solo noobs:",
               "kyutoryu (chev: 2, σ: 7.1)",
               "HungDaddy (chev: 1, σ: 2)",
               "------------------------------------------------------",
               "Teams constructed by simple draft",
               "------------------------------------------------------",
               "Final result:",
               "Team 1: Aposis, [DTG]BamBin0, Noody, MaTThiuS_82, HungDaddy",
               "Team 2: jauggy, reddragon2010, Dixinormus, SLOPPYGAGGER, kyutoryu"
             ],
             team_groups: %{
               1 => [
                 %{count: 1, group_rating: 0, members: ["HungDaddy"], ratings: [0]},
                 %{count: 1, group_rating: 8.26, members: ["MaTThiuS_82"], ratings: [8.26]},
                 %{count: 1, group_rating: 17.64, members: ["Noody"], ratings: [17.64]},
                 %{count: 1, group_rating: 20.06, members: ["[DTG]BamBin0"], ratings: [20.06]},
                 %{count: 1, group_rating: 20.42, members: ["Aposis"], ratings: [20.42]}
               ],
               2 => [
                 %{count: 1, group_rating: 12.25, members: ["kyutoryu"], ratings: [12.25]},
                 %{count: 1, group_rating: 8.89, members: ["SLOPPYGAGGER"], ratings: [8.89]},
                 %{count: 1, group_rating: 18.28, members: ["Dixinormus"], ratings: [18.28]},
                 %{count: 1, group_rating: 18.4, members: ["reddragon2010"], ratings: [18.4]},
                 %{count: 1, group_rating: 20.49, members: ["jauggy"], ratings: [20.49]}
               ]
             },
             team_players: %{
               1 => ["HungDaddy", "MaTThiuS_82", "Noody", "[DTG]BamBin0", "Aposis"],
               2 => ["kyutoryu", "SLOPPYGAGGER", "Dixinormus", "reddragon2010", "jauggy"]
             }
           }
  end

  test "Very strong captain will usually have noobiest noob" do
    # After brute force result is calculated there will be some remaining weak players to draft
    # The team that gets pick priority will be determined by a combination of team rating and captain rating
    # preferring lower for both
    expanded_group = [
      %{
        count: 2,
        members: ["LuBaee", "TimeContainer"],
        ratings: [14, 21],
        names: ["LuBaee", "TimeContainer"],
        uncertainties: [0, 1],
        ranks: [1, 1]
      },
      %{
        count: 1,
        members: ["colossus"],
        ratings: [22],
        names: ["colossus"],
        uncertainties: [2],
        ranks: [0]
      },
      %{
        count: 1,
        members: ["PotatoesHead"],
        ratings: [22],
        names: ["PotatoesHead"],
        uncertainties: [2],
        ranks: [0]
      },
      %{
        count: 1,
        members: ["onse"],
        ratings: [20],
        names: ["onse"],
        uncertainties: [3],
        ranks: [2]
      },
      %{
        count: 1,
        members: ["976"],
        ratings: [14],
        names: ["976"],
        uncertainties: [3],
        ranks: [2]
      },
      %{
        count: 1,
        members: ["HoldButyLeg"],
        ratings: [12],
        names: ["HoldButyLeg"],
        uncertainties: [7.5],
        ranks: [0]
      },
      %{
        count: 1,
        members: ["CowOfWar"],
        ratings: [3],
        names: ["CowOfWar"],
        uncertainties: [3],
        ranks: [2]
      },
      %{
        count: 1,
        members: ["DUFFY"],
        ratings: [34],
        names: ["DUFFY"],
        uncertainties: [3],
        ranks: [2]
      },
      %{
        count: 1,
        members: ["Orii"],
        ratings: [23],
        names: ["Orii"],
        uncertainties: [3],
        ranks: [2]
      },
      %{
        count: 1,
        members: ["Theo45"],
        ratings: [21],
        names: ["Theo45"],
        uncertainties: [3],
        ranks: [2]
      },
      %{
        count: 1,
        members: ["StinkBee"],
        ratings: [15],
        names: ["StinkBee"],
        uncertainties: [6.7],
        ranks: [2]
      },
      %{
        count: 1,
        members: ["Regithros"],
        ratings: [12],
        names: ["Regithros"],
        uncertainties: [5],
        ranks: [2]
      },
      %{
        count: 1,
        members: ["Darth"],
        ratings: [11],
        names: ["Darth"],
        uncertainties: [5],
        ranks: [2]
      },
      %{
        count: 1,
        members: ["Akio"],
        ratings: [10],
        names: ["Akio"],
        uncertainties: [5],
        ranks: [2]
      },
      %{
        count: 1,
        members: ["nubl"],
        ratings: [6],
        names: ["nubl"],
        uncertainties: [5],
        ranks: [2]
      }
    ]

    result = SplitNoobs.perform(expanded_group, 2)

    assert result.logs == [
             "------------------------------------------------------",
             "Algorithm: split_noobs",
             "------------------------------------------------------",
             "This algorithm will evenly distribute noobs and devalue them. Noobs are non-partied players that have either high uncertainty or 0 rating. Noobs will always be drafted last. For non-noobs, teams will prefer higher rating. For noobs, teams will prefer higher chevrons and lower uncertainty.",
             "------------------------------------------------------",
             "Parties: [LuBaee, TimeContainer]",
             "Solo noobs:",
             "StinkBee (chev: 3, σ: 6.7)",
             "HoldButyLeg (chev: 1, σ: 7.5)",
             "------------------------------------------------------",
             "Perform brute force with the following players to get the best score.",
             "Players: TimeContainer, LuBaee, DUFFY, Orii, colossus, PotatoesHead, Theo45, onse, 976, Regithros, Darth, Akio, nubl, CowOfWar",
             "------------------------------------------------------",
             "Brute force result:",
             "Team rating diff penalty: 1",
             "Broken party penalty: 0",
             "Score: 1 (lower is better)",
             "------------------------------------------------------",
             "Draft remaining players (ordered from best to worst).",
             "Remaining: StinkBee, HoldButyLeg",
             "------------------------------------------------------",
             "Final result:",
             "Team 1: CowOfWar, Akio, Regithros, Orii, DUFFY, LuBaee, TimeContainer, HoldButyLeg",
             "Team 2: nubl, Darth, 976, onse, Theo45, PotatoesHead, colossus, StinkBee"
           ]

    # Note DUFFY (Strongest captain) is on same team with noobiest noob HoldButyLeg
  end
end
