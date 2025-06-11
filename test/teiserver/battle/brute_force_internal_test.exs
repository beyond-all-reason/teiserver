defmodule Teiserver.Battle.BruteForceInternalTest do
  @moduledoc """
  Can run all balance tests via
  mix test --only balance_test
  """
  use Teiserver.DataCase, async: true
  @moduletag :balance_test
  alias Teiserver.Battle.Balance.BruteForce

  test "check for broken party" do
    party = ["kyutoryu", "fbots1998"]

    first_team = [
      %{name: "kyutoryu", rating: 12.25},
      %{name: "fbots1998", rating: 13.98},
      %{name: "Dixinormus", rating: 18.28},
      %{name: "HungDaddy", rating: 2.8}
    ]

    second_team = [
      %{name: "A", rating: 12.25},
      %{name: "fbots1998", rating: 13.98},
      %{name: "Dixinormus", rating: 18.28},
      %{name: "HungDaddy", rating: 2.8}
    ]

    third_team = [
      %{name: "A", rating: 12.25},
      %{name: "B", rating: 13.98},
      %{name: "Dixinormus", rating: 18.28},
      %{name: "HungDaddy", rating: 2.8}
    ]

    result = BruteForce.is_party_broken?(first_team, party)
    refute result

    result = BruteForce.is_party_broken?(second_team, party)
    assert result

    result = BruteForce.is_party_broken?(third_team, party)
    refute result
  end

  test "log parties" do
    parties = [["kyutoryu", "fbots1998"], ["Dix", "Dixinormus"]]
    result = BruteForce.log_parties(parties)

    assert result == "[kyutoryu, fbots1998], [Dix, Dixinormus]"
  end

  test "check for broken party with parties list" do
    parties = [["kyutoryu", "fbots1998"], ["Dix", "Dixinormus"]]

    first_team = [
      %{name: "kyutoryu", rating: 12.25},
      %{name: "fbots1998", rating: 13.98},
      %{name: "Dixinormus", rating: 18.28},
      %{name: "HungDaddy", rating: 2.8}
    ]

    result = BruteForce.count_broken_parties(first_team, parties)
    assert result == 1

    parties = [["kyutoryu", "fbots1998", "A"], ["Dix", "Dixinormus"]]
    result = BruteForce.count_broken_parties(first_team, parties)
    assert result == 2

    parties = [["A", "B", "C"], ["HungDaddy", "fbots1998"]]
    result = BruteForce.count_broken_parties(first_team, parties)
    assert result == 0
  end

  test "can get all combos" do
    input = %{
      parties: [["kyutoryu", "fbots1998"]],
      players: [
        %{name: "kyutoryu", rating: 12.25, id: 1},
        %{name: "fbots1998", rating: 13.98, id: 2},
        %{name: "Dixinormus", rating: 18.28, id: 3},
        %{name: "HungDaddy", rating: 2.8, id: 4},
        %{name: "SLOPPYGAGGER", rating: 8.89, id: 5},
        %{name: "jauggy", rating: 20.49, id: 6},
        %{name: "reddragon2010", rating: 18.4, id: 7},
        %{name: "Aposis", rating: 20.42, id: 8},
        %{name: "MaTThiuS_82", rating: 8.26, id: 9},
        %{name: "Noody", rating: 17.64, id: 10},
        %{name: "[DTG]BamBin0", rating: 20.06, id: 11},
        %{name: "barmalev", rating: 3.58, id: 12}
      ]
    }

    combos = BruteForce.potential_teams(length(input.players))
    assert length(combos) == 462
    first_combo = combos |> Enum.at(0)
    assert first_combo == [0, 1, 2, 3, 4, 5]
    players_with_index = Enum.with_index(input.players)
    first_potential_team = BruteForce.get_players_from_indexes(first_combo, players_with_index)

    assert first_potential_team == [
             %{name: "kyutoryu", rating: 12.25, id: 1},
             %{name: "fbots1998", rating: 13.98, id: 2},
             %{name: "Dixinormus", rating: 18.28, id: 3},
             %{name: "HungDaddy", rating: 2.8, id: 4},
             %{name: "SLOPPYGAGGER", rating: 8.89, id: 5},
             %{name: "jauggy", rating: 20.49, id: 6}
           ]

    result = BruteForce.score_combo(first_potential_team, input.players, input.parties)
    # Check the result map has required keys
    assert [
             :broken_party_penalty,
             :first_team,
             :rating_diff_penalty,
             :score,
             :second_team,
             :stdev_diff_penalty,
             :captain_diff_penalty
           ]
           |> Enum.all?(&Map.has_key?(result, &1))

    best_combo = BruteForce.get_best_combo(combos, input.players, input.parties)

    assert best_combo.broken_party_penalty == 0
    assert best_combo.rating_diff_penalty < 10
    result = BruteForce.standardise_result(best_combo, input.parties) |> Map.drop([:logs])

    assert [
             :team_groups,
             :team_players
           ]
           |> Enum.all?(&Map.has_key?(result, &1))
  end

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

    parties = BruteForce.get_parties(expanded_group)
    assert parties == [["kyutoryu", "fbots1998"]]
  end
end
