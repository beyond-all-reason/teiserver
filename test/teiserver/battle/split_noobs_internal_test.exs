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

    assert initial_state.experienced_players == [
             %{id: "kyutoryu", name: "kyutoryu", rating: 12.25, uncertainty: 0, rank: 1},
             %{id: "fbots1998", name: "fbots1998", rating: 13.98, uncertainty: 1, rank: 1},
             %{id: "Dixinormus", name: "Dixinormus", rating: 18.28, uncertainty: 2, rank: 0},
             %{id: "HungDaddy", name: "HungDaddy", rating: 2.8, uncertainty: 2, rank: 0},
             %{id: "SLOPPYGAGGER", name: "SLOPPYGAGGER", rating: 8.89, uncertainty: 3, rank: 2},
             %{id: "jauggy", name: "jauggy", rating: 20.49, uncertainty: 3, rank: 2},
             %{id: "reddragon2010", name: "reddragon2010", rating: 18.4, uncertainty: 3, rank: 2},
             %{id: "Aposis", name: "Aposis", rating: 20.42, uncertainty: 3, rank: 2},
             %{id: "MaTThiuS_82", name: "MaTThiuS_82", rating: 8.26, uncertainty: 3, rank: 2},
             %{id: "Noody", name: "Noody", rating: 17.64, uncertainty: 3, rank: 2},
             %{id: "[DTG]BamBin0", name: "[DTG]BamBin0", rating: 20.06, uncertainty: 3, rank: 2},
             %{id: "barmalev", name: "barmalev", rating: 3.58, uncertainty: 3, rank: 2}
           ]

    should_use = SplitNoobs.should_use_algo(initial_state, 2)
    assert should_use == :ok
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
               name: "kyutoryu",
               rating: 12.25,
               uncertainty: 7.1,
               rank: 1
             },
             %{
               id: "fbots1998",
               name: "fbots1998",
               rating: 13.98,
               uncertainty: 8,
               rank: 1
             },
             %{
               id: "Dixinormus",
               name: "Dixinormus",
               rating: 18.28,
               uncertainty: 8,
               rank: 2
             },
             %{
               id: "HungDaddy",
               name: "HungDaddy",
               rating: 2.8,
               uncertainty: 8,
               rank: 2
             },
             %{
               id: "SLOPPYGAGGER",
               name: "SLOPPYGAGGER",
               rating: 8.89,
               uncertainty: 3,
               rank: 2
             },
             %{
               id: "jauggy",
               name: "jauggy",
               rating: 20.49,
               uncertainty: 3,
               rank: 2
             },
             %{
               id: "reddragon2010",
               name: "reddragon2010",
               rating: 18.4,
               uncertainty: 3,
               rank: 2
             },
             %{
               id: "Aposis",
               name: "Aposis",
               rating: 20.42,
               uncertainty: 3,
               rank: 2
             },
             %{
               id: "MaTThiuS_82",
               name: "MaTThiuS_82",
               rating: 8.26,
               uncertainty: 3,
               rank: 2
             },
             %{
               id: "Noody",
               name: "Noody",
               rating: 17.64,
               uncertainty: 3,
               rank: 2
             },
             %{
               id: "[DTG]BamBin0",
               name: "[DTG]BamBin0",
               rating: 20.06,
               uncertainty: 3,
               rank: 2
             },
             %{
               id: "barmalev",
               name: "barmalev",
               rating: 3.58,
               uncertainty: 3,
               rank: 2
             }
           ]

    parties = SplitNoobs.get_parties(expanded_group)
    noobs = SplitNoobs.get_noobs(players, parties)

    assert parties == [["kyutoryu", "fbots1998"]]

    assert noobs == [
             %{id: "Dixinormus", name: "Dixinormus", rating: 18.28, uncertainty: 8, rank: 2},
             %{id: "HungDaddy", name: "HungDaddy", rating: 2.8, uncertainty: 8, rank: 2}
           ]

    experienced_players = SplitNoobs.get_experienced_players(players, noobs)

    assert experienced_players == [
             %{id: "kyutoryu", name: "kyutoryu", rating: 12.25, uncertainty: 7.1, rank: 1},
             %{id: "fbots1998", name: "fbots1998", rating: 13.98, uncertainty: 8, rank: 1},
             %{id: "SLOPPYGAGGER", name: "SLOPPYGAGGER", rating: 8.89, uncertainty: 3, rank: 2},
             %{id: "jauggy", name: "jauggy", rating: 20.49, uncertainty: 3, rank: 2},
             %{id: "reddragon2010", name: "reddragon2010", rating: 18.4, uncertainty: 3, rank: 2},
             %{id: "Aposis", name: "Aposis", rating: 20.42, uncertainty: 3, rank: 2},
             %{id: "MaTThiuS_82", name: "MaTThiuS_82", rating: 8.26, uncertainty: 3, rank: 2},
             %{id: "Noody", name: "Noody", rating: 17.64, uncertainty: 3, rank: 2},
             %{id: "[DTG]BamBin0", name: "[DTG]BamBin0", rating: 20.06, uncertainty: 3, rank: 2},
             %{id: "barmalev", name: "barmalev", rating: 3.58, uncertainty: 3, rank: 2}
           ]

    initial_state = SplitNoobs.get_initial_state(expanded_group)

    result = SplitNoobs.get_result(initial_state)

    assert result == %{
             broken_party_penalty: 0,
             first_team: [
               %{id: "HungDaddy", name: "HungDaddy", rating: 2.8, uncertainty: 8, rank: 2},
               %{id: "kyutoryu", name: "kyutoryu", rating: 12.25, uncertainty: 7.1, rank: 1},
               %{id: "fbots1998", name: "fbots1998", rating: 13.98, uncertainty: 8, rank: 1},
               %{id: "MaTThiuS_82", name: "MaTThiuS_82", rating: 8.26, uncertainty: 3, rank: 2},
               %{id: "Noody", name: "Noody", rating: 17.64, uncertainty: 3, rank: 2},
               %{id: "[DTG]BamBin0", name: "[DTG]BamBin0", rating: 20.06, uncertainty: 3, rank: 2}
             ],
             rating_diff_penalty: 0.4099999999999966,
             score: 0.4099999999999966,
             second_team: [
               %{id: "Dixinormus", name: "Dixinormus", rating: 18.28, uncertainty: 8, rank: 2},
               %{id: "SLOPPYGAGGER", name: "SLOPPYGAGGER", rating: 8.89, uncertainty: 3, rank: 2},
               %{id: "jauggy", name: "jauggy", rating: 20.49, uncertainty: 3, rank: 2},
               %{
                 id: "reddragon2010",
                 name: "reddragon2010",
                 rating: 18.4,
                 uncertainty: 3,
                 rank: 2
               },
               %{id: "Aposis", name: "Aposis", rating: 20.42, uncertainty: 3, rank: 2},
               %{id: "barmalev", name: "barmalev", rating: 3.58, uncertainty: 3, rank: 2}
             ]
           }

    standard_result = SplitNoobs.standardise_result(result, initial_state)

    assert standard_result == %{
             logs: [
               "------------------------------------------------------",
               "Algorithm: split_noobs",
               "------------------------------------------------------",
               "Parties: [kyutoryu, fbots1998]",
               "Solo Noobs: (Players not in parties that have either high uncertainty or 0 rating.)",
               "Dixinormus (chev: 3, σ: 8)",
               "HungDaddy (chev: 3, σ: 8)",
               "------------------------------------------------------",
               "Team 1: [DTG]BamBin0, Noody, MaTThiuS_82, fbots1998, kyutoryu, HungDaddy",
               "Team 2: barmalev, Aposis, reddragon2010, jauggy, SLOPPYGAGGER, Dixinormus",
               "Team rating diff penalty: 0.4",
               "Broken party penalty: 0",
               "Score: 0.4 (lower is better)"
             ],
             team_groups: %{
               1 => [
                 %{count: 1, group_rating: 2.8, members: ["HungDaddy"], ratings: [2.8]},
                 %{count: 1, group_rating: 12.25, members: ["kyutoryu"], ratings: [12.25]},
                 %{count: 1, group_rating: 13.98, members: ["fbots1998"], ratings: [13.98]},
                 %{count: 1, group_rating: 8.26, members: ["MaTThiuS_82"], ratings: [8.26]},
                 %{count: 1, group_rating: 17.64, members: ["Noody"], ratings: [17.64]},
                 %{count: 1, group_rating: 20.06, members: ["[DTG]BamBin0"], ratings: [20.06]}
               ],
               2 => [
                 %{count: 1, group_rating: 18.28, members: ["Dixinormus"], ratings: [18.28]},
                 %{count: 1, group_rating: 8.89, members: ["SLOPPYGAGGER"], ratings: [8.89]},
                 %{count: 1, group_rating: 20.49, members: ["jauggy"], ratings: [20.49]},
                 %{count: 1, group_rating: 18.4, members: ["reddragon2010"], ratings: [18.4]},
                 %{count: 1, group_rating: 20.42, members: ["Aposis"], ratings: [20.42]},
                 %{count: 1, group_rating: 3.58, members: ["barmalev"], ratings: [3.58]}
               ]
             },
             team_players: %{
               1 => ["HungDaddy", "kyutoryu", "fbots1998", "MaTThiuS_82", "Noody", "[DTG]BamBin0"],
               2 => [
                 "Dixinormus",
                 "SLOPPYGAGGER",
                 "jauggy",
                 "reddragon2010",
                 "Aposis",
                 "barmalev"
               ]
             }
           }
  end
end
