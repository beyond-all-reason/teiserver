defmodule Teiserver.Battle.BalanceLibInternalTest do
  @moduledoc """
  Can run all balance tests via
  mix test --only balance_test
  """
  use Teiserver.DataCase, async: true
  @moduletag :balance_test
  alias Teiserver.Battle.BalanceLib

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

    # loser_picks algo will hit the databases so let's just test with split_one_chevs
    result = BalanceLib.create_balance(fixed_groups, 2, algorithm: "split_one_chevs")
    assert result != nil
  end

  test "Handle groups with incomplete data in create_balance loser_pics" do
    [user1, user2, user3, user4, user5] = create_test_users()

    groups = [
      %{user1.id => 19, user2.id => 20},
      %{user3.id => 18},
      %{user4.id => 15},
      %{user5.id => 11}
    ]

    # loser_picks algo will hit the databases so let's just test with split_one_chevs
    result = BalanceLib.create_balance(groups, 2, algorithm: "loser_picks")
    assert result != nil
  end

  test "Handle groups with incomplete data in create_balance split_one_chevs" do
    [user1, user2, user3, user4, user5] = create_test_users()

    groups = [
      %{user1.id => 19, user2.id => 20},
      %{user3.id => 18},
      %{user4.id => 15},
      %{user5.id => 11}
    ]

    # loser_picks algo will hit the databases so let's just test with split_one_chevs
    result = BalanceLib.create_balance(groups, 2, algorithm: "split_one_chevs")
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

  defp create_test_users do
    Enum.map(1..5, fn k ->
      Teiserver.TeiserverTestLib.new_user("User_#{k}")
    end)
  end
end
