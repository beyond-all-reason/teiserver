defmodule Teiserver.Battle.SplitNoobsInternalTest do
  @moduledoc """
  Can run all balance tests via
  mix test --only balance_test
  """
  use ExUnit.Case
  @moduletag :balance_test
  alias Teiserver.Battle.Balance.SplitNoobs

  test "sort noobs" do
    noobs = [
      %{
        id: "kyutoryu",
        name: "kyutoryu",
        rating: 12.25,
        uncertainty: 7.1,
        rank: 0
      },
      %{
        id: "fbots1998",
        name: "fbots1998",
        rating: 13.98,
        uncertainty: 7,
        rank: 1
      },
      %{
        id: "Dixinormus",
        name: "Dixinormus",
        rating: 18.28,
        uncertainty: 8,
        rank: 1
      }
    ]

    result = SplitNoobs.sort_noobs(noobs)

    assert result == [
             %{id: "fbots1998", name: "fbots1998", rank: 1, uncertainty: 7, rating: 13.98},
             %{id: "Dixinormus", name: "Dixinormus", rank: 1, uncertainty: 8, rating: 18.28},
             %{id: "kyutoryu", name: "kyutoryu", rank: 0, uncertainty: 7.1, rating: 12.25}
           ]
  end

  test "split noobs should run" do
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

    initial_state = SplitNoobs.get_initial_state(expanded_group)

    assert initial_state.top_experienced == [
             %{
               id: "fbots1998",
               name: "fbots1998",
               rank: 1,
               rating: 13.98,
               uncertainty: 1,
               in_party?: true,
               index: 1
             },
             %{
               id: "kyutoryu",
               name: "kyutoryu",
               rank: 1,
               rating: 12.25,
               uncertainty: 0,
               in_party?: true,
               index: 2
             },
             %{
               id: "jauggy",
               name: "jauggy",
               rank: 2,
               rating: 20.49,
               uncertainty: 3,
               in_party?: false,
               index: 3
             },
             %{
               id: "Aposis",
               name: "Aposis",
               rank: 2,
               rating: 20.42,
               uncertainty: 3,
               in_party?: false,
               index: 4
             },
             %{
               id: "[DTG]BamBin0",
               name: "[DTG]BamBin0",
               rank: 2,
               rating: 20.06,
               uncertainty: 3,
               in_party?: false,
               index: 5
             },
             %{
               id: "reddragon2010",
               name: "reddragon2010",
               rank: 2,
               rating: 18.4,
               uncertainty: 3,
               in_party?: false,
               index: 6
             },
             %{
               id: "Dixinormus",
               name: "Dixinormus",
               rank: 0,
               rating: 18.28,
               uncertainty: 2,
               in_party?: false,
               index: 7
             },
             %{
               id: "Noody",
               name: "Noody",
               rank: 2,
               rating: 17.64,
               uncertainty: 3,
               in_party?: false,
               index: 8
             },
             %{
               id: "SLOPPYGAGGER",
               name: "SLOPPYGAGGER",
               rank: 2,
               rating: 8.89,
               uncertainty: 3,
               in_party?: false,
               index: 9
             },
             %{
               id: "MaTThiuS_82",
               name: "MaTThiuS_82",
               rank: 2,
               rating: 8.26,
               uncertainty: 3,
               in_party?: false,
               index: 10
             },
             %{
               id: "barmalev",
               name: "barmalev",
               rank: 2,
               rating: 3.58,
               uncertainty: 3,
               in_party?: false,
               index: 11
             },
             %{
               id: "HungDaddy",
               name: "HungDaddy",
               rank: 0,
               rating: 2.8,
               uncertainty: 2,
               in_party?: false,
               index: 12
             }
           ]

    should_use = SplitNoobs.should_use_algo(initial_state, 2)
    assert should_use == {:ok, :brute_force}
  end

  test "split noobs internal functions" do
    expanded_group = [
      %{
        count: 2,
        members: ["kyutoryu", "fbots1998"],
        ratings: [12.25, 13.98],
        names: ["kyutoryu", "fbots1998"],
        uncertainties: [7.1, 8],
        ranks: [1, 1]
      },
      %{
        count: 1,
        members: ["Dixinormus"],
        ratings: [18.28],
        names: ["Dixinormus"],
        uncertainties: [8],
        ranks: [2]
      },
      %{
        count: 1,
        members: ["HungDaddy"],
        ratings: [2.8],
        names: ["HungDaddy"],
        uncertainties: [8],
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

    players = SplitNoobs.flatten_members(expanded_group)

    assert players == [
             %{
               id: "kyutoryu",
               in_party?: true,
               name: "kyutoryu",
               rank: 1,
               rating: 8.975247524752481,
               uncertainty: 7.1
             },
             %{
               id: "fbots1998",
               in_party?: true,
               name: "fbots1998",
               rank: 1,
               rating: 2.768316831683173,
               uncertainty: 8
             },
             %{
               id: "Dixinormus",
               in_party?: false,
               name: "Dixinormus",
               rank: 2,
               rating: 3.6198019801980257,
               uncertainty: 8
             },
             %{
               id: "HungDaddy",
               in_party?: false,
               name: "HungDaddy",
               rank: 2,
               rating: 0.5544554455445553,
               uncertainty: 8
             },
             %{
               id: "SLOPPYGAGGER",
               in_party?: false,
               name: "SLOPPYGAGGER",
               rank: 2,
               rating: 8.89,
               uncertainty: 3
             },
             %{
               id: "jauggy",
               in_party?: false,
               name: "jauggy",
               rank: 2,
               rating: 20.49,
               uncertainty: 3
             },
             %{
               id: "reddragon2010",
               in_party?: false,
               name: "reddragon2010",
               rank: 2,
               rating: 18.4,
               uncertainty: 3
             },
             %{
               id: "Aposis",
               in_party?: false,
               name: "Aposis",
               rank: 2,
               rating: 20.42,
               uncertainty: 3
             },
             %{
               id: "MaTThiuS_82",
               in_party?: false,
               name: "MaTThiuS_82",
               rank: 2,
               rating: 8.26,
               uncertainty: 3
             },
             %{
               id: "Noody",
               in_party?: false,
               name: "Noody",
               rank: 2,
               rating: 17.64,
               uncertainty: 3
             },
             %{
               id: "[DTG]BamBin0",
               in_party?: false,
               name: "[DTG]BamBin0",
               rank: 2,
               rating: 20.06,
               uncertainty: 3
             },
             %{
               id: "barmalev",
               in_party?: false,
               name: "barmalev",
               rank: 2,
               rating: 3.58,
               uncertainty: 3
             }
           ]

    parties = SplitNoobs.get_parties(expanded_group)
    noobs = SplitNoobs.get_noobs(players)

    assert parties == [["kyutoryu", "fbots1998"]]

    assert noobs == [
             %{
               id: "Dixinormus",
               in_party?: false,
               name: "Dixinormus",
               rank: 2,
               rating: 3.6198019801980257,
               uncertainty: 8
             },
             %{
               id: "HungDaddy",
               in_party?: false,
               name: "HungDaddy",
               rank: 2,
               rating: 0.5544554455445553,
               uncertainty: 8
             }
           ]

    experienced_players = SplitNoobs.get_experienced_players(players, noobs)

    assert experienced_players == [
             %{
               id: "kyutoryu",
               in_party?: true,
               name: "kyutoryu",
               rank: 1,
               rating: 8.975247524752481,
               uncertainty: 7.1
             },
             %{
               id: "fbots1998",
               in_party?: true,
               name: "fbots1998",
               rank: 1,
               rating: 2.768316831683173,
               uncertainty: 8
             },
             %{
               id: "jauggy",
               in_party?: false,
               name: "jauggy",
               rank: 2,
               rating: 20.49,
               uncertainty: 3
             },
             %{
               id: "Aposis",
               in_party?: false,
               name: "Aposis",
               rank: 2,
               rating: 20.42,
               uncertainty: 3
             },
             %{
               id: "[DTG]BamBin0",
               in_party?: false,
               name: "[DTG]BamBin0",
               rank: 2,
               rating: 20.06,
               uncertainty: 3
             },
             %{
               id: "reddragon2010",
               in_party?: false,
               name: "reddragon2010",
               rank: 2,
               rating: 18.4,
               uncertainty: 3
             },
             %{
               id: "Noody",
               in_party?: false,
               name: "Noody",
               rank: 2,
               rating: 17.64,
               uncertainty: 3
             },
             %{
               id: "SLOPPYGAGGER",
               in_party?: false,
               name: "SLOPPYGAGGER",
               rank: 2,
               rating: 8.89,
               uncertainty: 3
             },
             %{
               id: "MaTThiuS_82",
               in_party?: false,
               name: "MaTThiuS_82",
               rank: 2,
               rating: 8.26,
               uncertainty: 3
             },
             %{
               id: "barmalev",
               in_party?: false,
               name: "barmalev",
               rank: 2,
               rating: 3.58,
               uncertainty: 3
             }
           ]

    initial_state = SplitNoobs.get_initial_state(expanded_group)

    result = SplitNoobs.get_result(initial_state)

    assert result |> Map.delete(:logs) == %{
             broken_party_penalty: 0.0,
             first_team: [
               %{
                 id: "HungDaddy",
                 in_party?: false,
                 name: "HungDaddy",
                 rank: 2,
                 rating: 0.5544554455445553,
                 uncertainty: 8
               },
               %{
                 id: "kyutoryu",
                 in_party?: true,
                 index: 1,
                 name: "kyutoryu",
                 rank: 1,
                 rating: 8.975247524752481,
                 uncertainty: 7.1
               },
               %{
                 id: "fbots1998",
                 in_party?: true,
                 index: 2,
                 name: "fbots1998",
                 rank: 1,
                 rating: 2.768316831683173,
                 uncertainty: 8
               },
               %{
                 id: "[DTG]BamBin0",
                 in_party?: false,
                 index: 5,
                 name: "[DTG]BamBin0",
                 rank: 2,
                 rating: 20.06,
                 uncertainty: 3
               },
               %{
                 id: "reddragon2010",
                 in_party?: false,
                 index: 6,
                 name: "reddragon2010",
                 rank: 2,
                 rating: 18.4,
                 uncertainty: 3
               },
               %{
                 id: "Noody",
                 in_party?: false,
                 index: 7,
                 name: "Noody",
                 rank: 2,
                 rating: 17.64,
                 uncertainty: 3
               }
             ],
             rating_diff_penalty: 6.203564356435635,
             score: 6.712413461911437,
             second_team: [
               %{
                 id: "Dixinormus",
                 in_party?: false,
                 name: "Dixinormus",
                 rank: 2,
                 rating: 3.6198019801980257,
                 uncertainty: 8
               },
               %{
                 id: "jauggy",
                 in_party?: false,
                 index: 3,
                 name: "jauggy",
                 rank: 2,
                 rating: 20.49,
                 uncertainty: 3
               },
               %{
                 id: "Aposis",
                 in_party?: false,
                 index: 4,
                 name: "Aposis",
                 rank: 2,
                 rating: 20.42,
                 uncertainty: 3
               },
               %{
                 id: "SLOPPYGAGGER",
                 in_party?: false,
                 index: 8,
                 name: "SLOPPYGAGGER",
                 rank: 2,
                 rating: 8.89,
                 uncertainty: 3
               },
               %{
                 id: "MaTThiuS_82",
                 in_party?: false,
                 index: 9,
                 name: "MaTThiuS_82",
                 rank: 2,
                 rating: 8.26,
                 uncertainty: 3
               },
               %{
                 id: "barmalev",
                 in_party?: false,
                 index: 10,
                 name: "barmalev",
                 rank: 2,
                 rating: 3.58,
                 uncertainty: 3
               }
             ],
             stdev_diff_penalty: 0.508849105475802
           }

    standard_result = SplitNoobs.standardise_result(result, initial_state)

    assert standard_result == %{
             logs: [
               "------------------------------------------------------",
               "Algorithm: split_noobs",
               "------------------------------------------------------",
               "This algorithm will evenly distribute noobs and devalue them. Noobs are non-partied players that have either high uncertainty or 0 rating. Noobs will always be drafted last. For non-noobs, teams will prefer higher rating. For noobs, teams will prefer higher chevrons and lower uncertainty.",
               "------------------------------------------------------",
               "Parties: (kyutoryu, fbots1998)",
               "Solo noobs:",
               "Dixinormus (3.6, chev: 2, σ: 8)",
               "HungDaddy (0.6, chev: 2, σ: 8)",
               "------------------------------------------------------",
               "Perform brute force with the following players to get the best score.",
               "Players: kyutoryu (9.0), fbots1998 (2.8), jauggy (20.5), Aposis (20.4), [DTG]BamBin0 (20.1), reddragon2010 (18.4), Noody (17.6), SLOPPYGAGGER (8.9), MaTThiuS_82 (8.3), barmalev (3.6)",
               "------------------------------------------------------",
               "Brute force result:",
               "Team rating diff penalty: 6.2",
               "Broken party penalty: 0.0",
               "Stdev diff penalty: 0.5",
               "Score: 6.7 (lower is better)",
               "------------------------------------------------------",
               "Draft remaining players (ordered from best to worst).",
               "Remaining: Dixinormus (3.6), HungDaddy (0.6)",
               "------------------------------------------------------",
               "Final result:",
               "Team 1: Noody, reddragon2010, [DTG]BamBin0, fbots1998, kyutoryu, HungDaddy",
               "Team 2: barmalev, MaTThiuS_82, SLOPPYGAGGER, Aposis, jauggy, Dixinormus"
             ],
             team_groups: %{
               1 => [
                 %{
                   count: 1,
                   group_rating: 0.5544554455445553,
                   members: ["HungDaddy"],
                   ratings: [0.5544554455445553]
                 },
                 %{
                   count: 1,
                   group_rating: 8.975247524752481,
                   members: ["kyutoryu"],
                   ratings: [8.975247524752481]
                 },
                 %{
                   count: 1,
                   group_rating: 2.768316831683173,
                   members: ["fbots1998"],
                   ratings: [2.768316831683173]
                 },
                 %{count: 1, group_rating: 20.06, members: ["[DTG]BamBin0"], ratings: [20.06]},
                 %{count: 1, group_rating: 18.4, members: ["reddragon2010"], ratings: [18.4]},
                 %{count: 1, group_rating: 17.64, members: ["Noody"], ratings: [17.64]}
               ],
               2 => [
                 %{
                   count: 1,
                   group_rating: 3.6198019801980257,
                   members: ["Dixinormus"],
                   ratings: [3.6198019801980257]
                 },
                 %{count: 1, group_rating: 20.49, members: ["jauggy"], ratings: [20.49]},
                 %{count: 1, group_rating: 20.42, members: ["Aposis"], ratings: [20.42]},
                 %{count: 1, group_rating: 8.89, members: ["SLOPPYGAGGER"], ratings: [8.89]},
                 %{count: 1, group_rating: 8.26, members: ["MaTThiuS_82"], ratings: [8.26]},
                 %{count: 1, group_rating: 3.58, members: ["barmalev"], ratings: [3.58]}
               ]
             },
             team_players: %{
               1 => [
                 "HungDaddy",
                 "kyutoryu",
                 "fbots1998",
                 "[DTG]BamBin0",
                 "reddragon2010",
                 "Noody"
               ],
               2 => ["Dixinormus", "jauggy", "Aposis", "SLOPPYGAGGER", "MaTThiuS_82", "barmalev"]
             }
           }
  end
end
