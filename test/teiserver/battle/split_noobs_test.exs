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

    # This test passes if the top three players (all rated 20+) are NOT on the same team
    assert result == %{
             team_groups: %{
               1 => [
                 %{count: 1, group_rating: 13.98, members: ["fbots1998"], ratings: [13.98]},
                 %{count: 1, group_rating: 20.06, members: ["[DTG]BamBin0"], ratings: [20.06]},
                 %{count: 1, group_rating: 18.4, members: ["reddragon2010"], ratings: [18.4]},
                 %{count: 1, members: ["Dixinormus"], ratings: [18.28], group_rating: 18.28},
                 %{count: 1, group_rating: 8.89, members: ["SLOPPYGAGGER"], ratings: [8.89]},
                 %{count: 1, group_rating: 2.8, members: ["HungDaddy"], ratings: [2.8]}
               ],
               2 => [
                 %{count: 1, members: ["kyutoryu"], ratings: [12.25], group_rating: 12.25},
                 %{count: 1, members: ["jauggy"], ratings: [20.49], group_rating: 20.49},
                 %{count: 1, group_rating: 20.42, members: ["Aposis"], ratings: [20.42]},
                 %{count: 1, group_rating: 17.64, members: ["Noody"], ratings: [17.64]},
                 %{count: 1, members: ["MaTThiuS_82"], ratings: [8.26], group_rating: 8.26},
                 %{count: 1, group_rating: 3.58, members: ["barmalev"], ratings: [3.58]}
               ]
             },
             team_players: %{
               1 => [
                 "fbots1998",
                 "[DTG]BamBin0",
                 "reddragon2010",
                 "Dixinormus",
                 "SLOPPYGAGGER",
                 "HungDaddy"
               ],
               2 => ["kyutoryu", "jauggy", "Aposis", "Noody", "MaTThiuS_82", "barmalev"]
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
               "kyutoryu (9.0, chev: 1, σ: 7.1)",
               "HungDaddy (0, chev: 0, σ: 2)",
               "------------------------------------------------------",
               "Teams constructed by simple draft",
               "------------------------------------------------------",
               "Final result:",
               "Team 1: Aposis, [DTG]BamBin0, Noody, MaTThiuS_82, HungDaddy",
               "Team 2: jauggy, reddragon2010, Dixinormus, SLOPPYGAGGER, kyutoryu"
             ],
             team_groups: %{
               1 => [
                 %{
                   count: 1,
                   group_rating: 0,
                   members: ["HungDaddy"],
                   ratings: [0]
                 },
                 %{
                   count: 1,
                   group_rating: 8.26,
                   members: ["MaTThiuS_82"],
                   ratings: [8.26]
                 },
                 %{
                   count: 1,
                   group_rating: 17.64,
                   members: ["Noody"],
                   ratings: [17.64]
                 },
                 %{
                   count: 1,
                   group_rating: 20.06,
                   members: ["[DTG]BamBin0"],
                   ratings: [20.06]
                 },
                 %{
                   count: 1,
                   group_rating: 20.42,
                   members: ["Aposis"],
                   ratings: [20.42]
                 }
               ],
               2 => [
                 %{
                   count: 1,
                   group_rating: 8.975247524752481,
                   members: ["kyutoryu"],
                   ratings: [8.975247524752481]
                 },
                 %{
                   count: 1,
                   group_rating: 8.89,
                   members: ["SLOPPYGAGGER"],
                   ratings: [8.89]
                 },
                 %{
                   count: 1,
                   group_rating: 18.28,
                   members: ["Dixinormus"],
                   ratings: [18.28]
                 },
                 %{
                   count: 1,
                   group_rating: 18.4,
                   members: ["reddragon2010"],
                   ratings: [18.4]
                 },
                 %{
                   count: 1,
                   group_rating: 20.49,
                   members: ["jauggy"],
                   ratings: [20.49]
                 }
               ]
             },
             team_players: %{
               1 => [
                 "HungDaddy",
                 "MaTThiuS_82",
                 "Noody",
                 "[DTG]BamBin0",
                 "Aposis"
               ],
               2 => [
                 "kyutoryu",
                 "SLOPPYGAGGER",
                 "Dixinormus",
                 "reddragon2010",
                 "jauggy"
               ]
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
             "Parties: (LuBaee, TimeContainer)",
             "Solo noobs:",
             "StinkBee (14.6, chev: 2, σ: 6.7)",
             "HoldButyLeg (5.9, chev: 0, σ: 7.5)",
             "------------------------------------------------------",
             "Perform brute force with the following players to get the best score.",
             "Players: TimeContainer (21), LuBaee (14), DUFFY (34), Orii (23), colossus (22), PotatoesHead (22), Theo45 (21), onse (20), 976 (14), Regithros (12), Darth (11), Akio (10), nubl (6), CowOfWar (3)",
             "------------------------------------------------------",
             "Brute force result:",
             "Team rating diff penalty: 1",
             "Broken party penalty: 0.0",
             "Stdev diff penalty: 0.1",
             "Score: 1.1 (lower is better)",
             "------------------------------------------------------",
             "Draft remaining players (ordered from best to worst).",
             "Remaining: StinkBee (14.6), HoldButyLeg (5.9)",
             "------------------------------------------------------",
             "Final result:",
             "Team 1: Akio, Darth, Regithros, 976, DUFFY, LuBaee, TimeContainer, HoldButyLeg",
             "Team 2: CowOfWar, nubl, onse, Theo45, PotatoesHead, colossus, Orii, StinkBee"
           ]

    # Note DUFFY (Strongest captain) is on same team with noobiest noob HoldButyLeg
  end

  test "Imbalanced captains will use brute force" do
    # If the leader is two times the rating of the next best, use brute force instead of draft

    expanded_group = [
      %{
        count: 1,
        members: ["Raigeki"],
        ratings: [59.85],
        names: ["Raigeki"],
        uncertainties: [0],
        ranks: [1]
      },
      %{
        count: 1,
        members: ["FRODODOR"],
        ratings: [25.68],
        names: ["FRODODOR"],
        uncertainties: [0],
        ranks: [1]
      },
      %{
        count: 1,
        members: ["MrKicks"],
        ratings: [0.87],
        names: ["MrKicks"],
        uncertainties: [2],
        ranks: [0]
      },
      %{
        count: 1,
        members: ["UnreasonableIkko"],
        ratings: [5.99],
        names: ["UnreasonableIkko"],
        uncertainties: [2],
        ranks: [0]
      },
      %{
        count: 1,
        members: ["BIL"],
        ratings: [16.82],
        names: ["BIL"],
        uncertainties: [8.3],
        ranks: [0]
      },
      %{
        count: 1,
        members: ["Larch"],
        ratings: [22.04],
        names: ["Larch"],
        uncertainties: [3],
        ranks: [2]
      },
      %{
        count: 1,
        members: ["Cobaltstore"],
        ratings: [13.64],
        names: ["Cobaltstore"],
        uncertainties: [1],
        ranks: [0]
      },
      %{
        count: 1,
        members: ["SHAAARKBATE"],
        ratings: [9.91],
        names: ["SHAAARKBATE"],
        uncertainties: [3],
        ranks: [2]
      },
      %{
        count: 1,
        members: ["Engolianth"],
        ratings: [26.99],
        names: ["Engolianth"],
        uncertainties: [3],
        ranks: [2]
      },
      %{
        count: 1,
        members: ["ColorlesScum"],
        ratings: [2.31],
        names: ["ColorlesScum"],
        uncertainties: [3],
        ranks: [2]
      },
      %{
        count: 1,
        members: ["Renkei"],
        ratings: [1.15],
        names: ["Renkei"],
        uncertainties: [3],
        ranks: [2]
      },
      %{
        count: 1,
        members: ["quest"],
        ratings: [13.07],
        names: ["quest"],
        uncertainties: [2],
        ranks: [2]
      },
      %{
        count: 1,
        members: ["illusiveman2024"],
        ratings: [6.98],
        names: ["illusiveman2024"],
        uncertainties: [5],
        ranks: [2]
      },
      %{
        count: 1,
        members: ["shoeofobama"],
        ratings: [23.94],
        names: ["shoeofobama"],
        uncertainties: [5],
        ranks: [2]
      },
      %{
        count: 1,
        members: ["Demodred"],
        ratings: [25.97],
        names: ["Demodred"],
        uncertainties: [5],
        ranks: [2]
      },
      %{
        count: 1,
        members: ["Artifical_Banana"],
        ratings: [20.14],
        names: ["Artifical_Banana"],
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
             "Parties: None",
             "Solo noobs:",
             "BIL (0.3, chev: 0, σ: 8.3)",
             "------------------------------------------------------",
             "Perform brute force with the following players to get the best score.",
             "Players: Raigeki (59.9), Engolianth (27.0), Demodred (26.0), FRODODOR (25.7), shoeofobama (23.9), Larch (22.0), Artifical_Banana (20.1), Cobaltstore (13.6), quest (13.1), SHAAARKBATE (9.9), illusiveman2024 (7.0), UnreasonableIkko (6.0), ColorlesScum (2.3), Renkei (1.2)",
             "------------------------------------------------------",
             "Brute force result:",
             "Team rating diff penalty: 1.5",
             "Broken party penalty: 0.0",
             "Stdev diff penalty: 13.7",
             "Score: 15.2 (lower is better)",
             "------------------------------------------------------",
             "Draft remaining players (ordered from best to worst).",
             "Remaining: MrKicks (0.9), BIL (0.3)",
             "------------------------------------------------------",
             "Final result:",
             "Team 1: UnreasonableIkko, illusiveman2024, SHAAARKBATE, quest, Cobaltstore, Artifical_Banana, Raigeki, BIL",
             "Team 2: Renkei, ColorlesScum, Larch, shoeofobama, FRODODOR, Demodred, Engolianth, MrKicks"
           ]
  end

  test "can handle party with high sd." do
    expanded_group = [
      %{
        count: 2,
        members: ["Blodir", "PassionFruit"],
        ratings: [52, 17],
        names: ["Blodir", "PassionFruit"],
        uncertainties: [0, 0],
        ranks: [1, 1]
      },
      %{
        count: 1,
        members: ["Sargeras"],
        ratings: [32],
        names: ["Sargeras"],
        uncertainties: [0],
        ranks: [1]
      },
      %{
        count: 1,
        members: ["Flaka"],
        ratings: [28],
        names: ["Flaka"],
        uncertainties: [0],
        ranks: [1]
      }
    ]

    result = SplitNoobs.perform(expanded_group, 2)

    # Test passes if broken party is 0
    assert result.logs == [
             "------------------------------------------------------",
             "Algorithm: split_noobs",
             "------------------------------------------------------",
             "This algorithm will evenly distribute noobs and devalue them. Noobs are non-partied players that have either high uncertainty or 0 rating. Noobs will always be drafted last. For non-noobs, teams will prefer higher rating. For noobs, teams will prefer higher chevrons and lower uncertainty.",
             "------------------------------------------------------",
             "Parties: (Blodir, PassionFruit)",
             "Solo Noobs: None",
             "------------------------------------------------------",
             "Perform brute force with the following players to get the best score.",
             "Players: Blodir (52), PassionFruit (17), Sargeras (32), Flaka (28)",
             "------------------------------------------------------",
             "Brute force result:",
             "Team rating diff penalty: 9",
             "Broken party penalty: 0.0",
             "Stdev diff penalty: 31.0",
             "Score: 40.0 (lower is better)",
             "------------------------------------------------------",
             "Draft remaining players (ordered from best to worst).",
             "Remaining: ",
             "------------------------------------------------------",
             "Final result:",
             "Team 1: PassionFruit, Blodir",
             "Team 2: Flaka, Sargeras"
           ]
  end
end
