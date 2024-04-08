defmodule Teiserver.Battle.ForcePartyBalanceTest do
  @moduledoc """
  Can run tests in this file only by
  mix test test/teiserver/battle/force_party_balance_test.exs
  """
  use Teiserver.DataCase, async: true
  alias Teiserver.Battle.BalanceLib

  @algorithm "force_party"

  test "simple users" do
    result =
      BalanceLib.create_balance(
        [
          # Our high tier party
          %{101 => 52, 102 => 50, 103 => 49},

          # Our other high tier party
          %{104 => 51, 105 => 50, 106 => 50},

          # Other players, a range of ratings
          %{107 => 28},
          %{108 => 27},
          %{109 => 26},
          %{110 => 25},
          %{111 => 21},
          %{112 => 19},
          %{113 => 16},
          %{114 => 15},
          %{115 => 14},
          %{116 => 8}
        ],
        2,
        algorithm: @algorithm
      )

    # Right now we just want to assert it doesn't error out
    assert result != false
  end
end
