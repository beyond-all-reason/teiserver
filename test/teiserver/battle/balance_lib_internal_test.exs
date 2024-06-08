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
               user1.id => %{name: "User_1", rank: 0, rating: 19},
               user2.id => %{name: "User_2", rank: 0, rating: 20}
             },
             %{user3.id => %{name: "User_3", rank: 0, rating: 18}},
             %{user4.id => %{name: "User_4", rank: 0, rating: 15}},
             %{user5.id => %{name: "User_5", rank: 0, rating: 11}}
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

  defp create_test_users do
    Enum.map(1..5, fn k ->
      Teiserver.TeiserverTestLib.new_user("User_#{k}")
    end)
  end
end
