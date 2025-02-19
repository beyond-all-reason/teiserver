defmodule Teiserver.Battle.AutoBalanceInternalTest do
  @moduledoc """
  Can run all balance tests via
  mix test --only balance_test
  """
  use Teiserver.DataCase, async: true
  @moduletag :balance_test
  alias Teiserver.Battle.Balance.AutoBalance
  require Logger

  test "Able to get parties count" do
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
        count: 2,
        members: ["Dixinormus", "SLOPPYGAGGER"],
        ratings: [18.28, 0],
        names: ["Dixinormus", "SLOPPYGAGGER"],
        uncertainties: [2, 4],
        ranks: [0, 0]
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

    result = AutoBalance.get_parties_count(expanded_group)
    assert result == 2
  end

  test "Able to detect an op party" do
    # The two best players are in the same party
    expanded_group = [
      %{
        count: 2,
        members: ["kyutoryu", "fbots1998"],
        ratings: [50, 49],
        names: ["kyutoryu", "fbots1998"],
        uncertainties: [0, 1],
        ranks: [1, 1]
      },
      %{
        count: 2,
        members: ["Dixinormus", "SLOPPYGAGGER"],
        ratings: [18.28, 0],
        names: ["Dixinormus", "SLOPPYGAGGER"],
        uncertainties: [2, 4],
        ranks: [0, 0]
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

    players = AutoBalance.flatten_members(expanded_group)
    has_op_party? = AutoBalance.has_op_party?(players)
    assert has_op_party? == true
  end

  test "Able to determine when no op party" do
    # The two best players are in different parties
    expanded_group = [
      %{
        count: 2,
        members: ["kyutoryu", "fbots1998"],
        ratings: [50, 49],
        names: ["kyutoryu", "fbots1998"],
        uncertainties: [0, 1],
        ranks: [1, 1]
      },
      %{
        count: 2,
        members: ["Dixinormus", "SLOPPYGAGGER"],
        ratings: [60, 0],
        names: ["Dixinormus", "SLOPPYGAGGER"],
        uncertainties: [2, 4],
        ranks: [0, 0]
      }
    ]

    players = AutoBalance.flatten_members(expanded_group)
    has_op_party? = AutoBalance.has_op_party?(players)
    assert has_op_party? == false

    # The number of players in lobby is less than two
    expanded_group = [
      %{
        count: 1,
        members: ["MaTThiuS_82"],
        ratings: [8.26],
        names: ["MaTThiuS_82"],
        uncertainties: [3],
        ranks: [2]
      }
    ]

    players = AutoBalance.flatten_members(expanded_group)
    has_op_party? = AutoBalance.has_op_party?(players)
    assert has_op_party? == false
  end
end
