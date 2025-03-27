defmodule Teiserver.Battle.BalanceLibInternalTest do
  @moduledoc """
  Can run all balance tests via
  mix test --only balance_test
  """
  use Teiserver.DataCase, async: true
  @moduletag :balance_test
  alias Teiserver.Battle.BalanceLib
  require Logger

  test "Able to standardise groups with incomplete data" do
    [user1, user2, user3, user4, user5] = create_test_users()

    groups = [
      %{user1.id => 19, user2.id => 20},
      %{user3.id => 18},
      %{user4.id => 15},
      %{user5.id => 11}
    ]

    fixed_groups = BalanceLib.standardise_groups(groups)

    assert fixed_groups == [
             %{
               user1.id => %{name: user1.name, rank: 0, rating: 19, uncertainty: 0},
               user2.id => %{name: user2.name, rank: 0, rating: 20, uncertainty: 0}
             },
             %{user3.id => %{name: user3.name, rank: 0, rating: 18, uncertainty: 0}},
             %{user4.id => %{name: user4.name, rank: 0, rating: 15, uncertainty: 0}},
             %{user5.id => %{name: user5.name, rank: 0, rating: 11, uncertainty: 0}}
           ]
  end

  test "Handle groups with incomplete data in create_balance loser_picks" do
    [user1, user2, user3, user4, user5] = create_test_users()

    groups = [
      %{user1.id => 19, user2.id => 20},
      %{user3.id => 18},
      %{user4.id => 15},
      %{user5.id => 11}
    ]

    result = BalanceLib.create_balance(groups, 2, algorithm: "loser_picks")
    assert result != nil
  end

  test "does team have parties" do
    team = [
      %{count: 2, group_rating: 13, members: [1, 4], ratings: [8, 5]}
    ]

    assert BalanceLib.team_has_parties?(team)

    team = [
      %{count: 1, group_rating: 8, members: [2], ratings: [8]}
    ]

    refute BalanceLib.team_has_parties?(team)
  end

  test "does team_groups in balance result have parties" do
    team_groups = %{
      1 => [
        %{count: 2, group_rating: 13, members: [1, 4], ratings: [8, 5]}
      ],
      2 => [
        %{count: 1, group_rating: 6, members: [2], ratings: [6]}
      ]
    }

    assert BalanceLib.balanced_teams_has_parties?(team_groups)

    team_groups = %{
      1 => [
        %{count: 1, group_rating: 8, members: [1], ratings: [8]},
        %{count: 1, group_rating: 8, members: [2], ratings: [8]}
      ],
      2 => [
        %{count: 1, group_rating: 6, members: [3], ratings: [6]},
        %{count: 1, group_rating: 8, members: [4], ratings: [8]}
      ]
    }

    refute BalanceLib.balanced_teams_has_parties?(team_groups)

    team_groups = %{
      1 => [
        %{count: 1, group_rating: 8, members: [1], ratings: [8]},
        %{count: 1, group_rating: 8, members: [2], ratings: [8]}
      ],
      2 => [
        %{count: 1, group_rating: 13, members: [3], ratings: [6]},
        %{count: 2, group_rating: 8, members: [4, 5], ratings: [8, 0]}
      ]
    }

    assert BalanceLib.balanced_teams_has_parties?(team_groups)
  end

  test "Allowed algorithms" do
    is_moderator = true
    result = BalanceLib.get_allowed_algorithms(is_moderator)

    assert result == [
             "default",
             "auto",
             "brute_force",
             "force_party",
             "loser_picks",
             "respect_avoids",
             "split_noobs"
           ]

    is_moderator = false
    result = BalanceLib.get_allowed_algorithms(is_moderator)
    assert result == ["default", "auto", "loser_picks", "respect_avoids", "split_noobs"]
  end

  test "Validate result" do
    balance_result = %{
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
      team_sizes: %{},
      deviation: 0,
      means: %{1 => 6.5, 2 => 6.5},
      stdevs: %{1 => 1.5, 2 => 0.5},
      has_parties?: false
    }

    groups = [
      %{1 => %{rating: 5}},
      %{2 => %{rating: 6}},
      %{3 => %{rating: 7}},
      %{4 => %{rating: 8}}
    ]

    team_count = 2
    opts = [algorithm: "loser_picks"]

    # Add comment so that someone viewing test logs knows it's a deliberate errror
    Logger.error("The following error is part of a test inside BalanceLibInternalTest.")
    result = BalanceLib.validate_result(balance_result, groups, team_count, opts)
    assert result == balance_result
  end

  defp create_test_users do
    Enum.map(1..5, fn k ->
      Teiserver.TeiserverTestLib.new_user("User_#{k}")
    end)
  end
end
