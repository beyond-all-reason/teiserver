defmodule Teiserver.Battle.ForcePartyBalanceTest do
  @moduledoc """
  Can run tests in this file only by
  mix test test/teiserver/battle/force_party_balance_test.exs
  """
  use Teiserver.DataCase, async: true
  @moduletag :balance_test
  alias Teiserver.Battle.BalanceLib

  @algorithm "force_party"

  test "simple users" do
    result =
      BalanceLib.create_balance(
        [
          # Our high tier party
          %{101 => %{rating: 52}, 102 => %{rating: 50}, 103 => %{rating: 49}},

          # Our other high tier party
          %{104 => %{rating: 51}, 105 => %{rating: 50}, 106 => %{rating: 50}},

          # Other players, a range of ratings
          %{107 => %{rating: 28}},
          %{108 => %{rating: 27}},
          %{109 => %{rating: 26}},
          %{110 => %{rating: 25}},
          %{111 => %{rating: 21}},
          %{112 => %{rating: 19}},
          %{113 => %{rating: 16}},
          %{114 => %{rating: 15}},
          %{115 => %{rating: 14}},
          %{116 => %{rating: 8}}
        ],
        2,
        algorithm: @algorithm
      )

    # Right now we just want to assert it doesn't error out
    assert result != false
  end
end
