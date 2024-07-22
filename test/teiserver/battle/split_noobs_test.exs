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
end
