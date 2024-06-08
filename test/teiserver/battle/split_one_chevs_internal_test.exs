defmodule Teiserver.Battle.SplitOneChevsInternalTest do
  @moduledoc """
  This tests the internal functions of SplitOneChevs
  Can run tests in this file only by
  mix test test/teiserver/battle/split_one_chevs_internal_test.exs
  """
  use ExUnit.Case
  @moduletag :balance_test
  alias Teiserver.Battle.Balance.SplitOneChevs

  test "perform" do
    expanded_group = [
      %{
        count: 2,
        members: ["Pro1", "Noob1"],
        group_rating: 13,
        ratings: [8, 5],
        ranks: [1, 0],
        names: ["Pro1", "Noob1"]
      },
      %{
        count: 1,
        members: ["Noob2"],
        group_rating: 6,
        ratings: [6],
        ranks: [0],
        names: ["Noob2"]
      },
      %{
        count: 1,
        members: ["Noob3"],
        group_rating: 7,
        ratings: [17],
        ranks: [0],
        names: ["Noob3"]
      }
    ]

    result = SplitOneChevs.perform(expanded_group, 2)

    assert result.team_groups == %{
             1 => [
               %{count: 1, group_rating: 6, members: ["Noob2"], ratings: [6]},
               %{count: 1, group_rating: 8, members: ["Pro1"], ratings: [8]}
             ],
             2 => [
               %{count: 1, group_rating: 5, members: ["Noob1"], ratings: [5]},
               %{count: 1, group_rating: 17, members: ["Noob3"], ratings: [17]}
             ]
           }
  end

  test "sort members" do
    members = [
      %{rating: 8, rank: 4, member_id: 100},
      %{rating: 5, rank: 0, member_id: 4},
      %{rating: 6, rank: 0, member_id: 2},
      %{rating: 17, rank: 0, member_id: 3}
    ]

    result = SplitOneChevs.sort_members(members)

    assert result == [
             %{rating: 8, rank: 4, member_id: 100},
             %{rating: 17, rank: 0, member_id: 3},
             %{rating: 6, rank: 0, member_id: 2},
             %{rating: 5, rank: 0, member_id: 4}
           ]
  end

  test "assign teams" do
    members = [
      %{rating: 8, rank: 4, member_id: 100, name: "100"},
      %{rating: 5, rank: 0, member_id: 4, name: "4"},
      %{rating: 6, rank: 0, member_id: 2, name: "2"},
      %{rating: 17, rank: 0, member_id: 3, name: "3"}
    ]

    result = SplitOneChevs.assign_teams(members, 2)

    assert result.teams == [
             %{
               members: [
                 %{rating: 17, rank: 0, member_id: 3, name: "3"},
                 %{rating: 8, rank: 4, member_id: 100, name: "100"}
               ],
               team_id: 1
             },
             %{
               members: [
                 %{rating: 6, rank: 0, member_id: 2, name: "2"},
                 %{rating: 5, rank: 0, member_id: 4, name: "4"}
               ],
               team_id: 2
             }
           ]
  end

  test "create empty teams" do
    result = SplitOneChevs.create_empty_teams(3)

    assert result == [
             %{members: [], team_id: 1},
             %{members: [], team_id: 2},
             %{members: [], team_id: 3}
           ]
  end
end
