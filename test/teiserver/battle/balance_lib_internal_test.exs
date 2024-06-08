defmodule Teiserver.Battle.BalanceLibInternalTest do
  @moduledoc """
  Can run all balance tests via
  mix test --only balance_test
  """
  use ExUnit.Case
  import Mock
  @moduletag :balance_test
  alias Teiserver.Battle.BalanceLib

  setup_with_mocks([
    {Teiserver.Account, [:passthrough],
     [get_user_by_id: fn member_id -> get_user_by_id_mock(member_id) end]}
  ]) do
    :ok
  end

  test "Able to standardise groups with incomplete data" do
    groups = [
      %{1 => 19, 2 => 20},
      %{3 => 18},
      %{4 => 15},
      %{5 => 11}
    ]

    fixed_groups = BalanceLib.standardise_groups(groups)

    assert fixed_groups == [
             %{
               1 => %{name: "User_1", rank: 0, rating: 19},
               2 => %{name: "User_2", rank: 0, rating: 20}
             },
             %{3 => %{name: "User_3", rank: 0, rating: 18}},
             %{4 => %{name: "User_4", rank: 0, rating: 15}},
             %{5 => %{name: "User_5", rank: 0, rating: 11}}
           ]

    # loser_picks algo will hit the databases so let's just test with split_one_chevs
    result = BalanceLib.create_balance(fixed_groups, 2, algorithm: "split_one_chevs")
    assert result != nil
  end

  test "Handle groups with incomplete data in create_balance" do
    groups = [
      %{1 => 19, 2 => 20},
      %{3 => 18},
      %{4 => 15},
      %{5 => 11}
    ]

    # loser_picks algo will hit the databases so let's just test with split_one_chevs
    result = BalanceLib.create_balance(groups, 2, algorithm: "split_one_chevs")
    assert result != nil
  end

  defp get_user_by_id_mock(user_id) do
    %{rank: 0, name: "User_#{user_id}"}
  end
end
