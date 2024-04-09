defmodule Teiserver.Battle.BalanceLibTest do
  @moduledoc """
  Can run tests in this file only by
  mix test test/teiserver/battle/balance_lib_test.exs
  """
  use Teiserver.DataCase, async: true
  @moduletag :balance_test
  alias Teiserver.Battle.BalanceLib

  test "balance algorithms - no players" do
    # We don't care about the result, just that they don't error
    BalanceLib.algorithm_modules()
    |> Map.keys()
    |> Enum.each(fn algorithm_name ->
      result =
        BalanceLib.create_balance(
          [],
          2,
          algorithm: algorithm_name
        )

      assert result != nil
    end)
  end

  test "balance algorithms - one player" do
    # We don't care about the result, just that they don't error
    BalanceLib.algorithm_modules()
    |> Map.keys()
    |> Enum.each(fn algorithm_name ->
      result =
        BalanceLib.create_balance(
          [
            %{1 => %{rating: 5}}
          ],
          2,
          algorithm: algorithm_name
        )

      assert result != nil
    end)
  end

  test "balance algorithms - 2v2" do
    # We don't care about the result, just that they don't error
    BalanceLib.algorithm_modules()
    |> Map.keys()
    |> Enum.each(fn algorithm_name ->
      result =
        BalanceLib.create_balance(
          [
            %{1 => %{rating: 5}},
            %{2 => %{rating: 6}},
            %{3 => %{rating: 7}},
            %{4 => %{rating: 8}}
          ],
          2,
          algorithm: algorithm_name
        )

      assert result != nil
    end)
  end

  test "balance algorithms - ffa" do
    # We don't care about the result, just that they don't error
    BalanceLib.algorithm_modules()
    |> Map.keys()
    |> Enum.each(fn algorithm_name ->
      result =
        BalanceLib.create_balance(
          [
            %{1 => %{rating: 5}},
            %{2 => %{rating: 6}},
            %{3 => %{rating: 7}},
            %{4 => %{rating: 8}}
          ],
          4,
          algorithm: algorithm_name
        )

      assert result != nil
    end)
  end

  test "balance algorithms - team ffa" do
    # We don't care about the result, just that they don't error
    BalanceLib.algorithm_modules()
    |> Map.keys()
    |> Enum.each(fn algorithm_name ->
      result =
        BalanceLib.create_balance(
          [
            %{1 => %{rating: 5}},
            %{2 => %{rating: 6}},
            %{3 => %{rating: 7}},
            %{4 => %{rating: 8}},
            %{5 => %{rating: 9}},
            %{6 => %{rating: 9}}
          ],
          3,
          algorithm: algorithm_name
        )

      assert result != nil
    end)
  end

  test "balance algorithms - bigger game with groups" do
    # We don't care about the result, just that they don't error
    BalanceLib.algorithm_modules()
    |> Map.keys()
    |> Enum.each(fn algorithm_name ->
      result =
        BalanceLib.create_balance(
          [
            # Two high tier players partied together
            %{101 => %{rating: 41}, 102 => %{rating: 35}},

            # A bunch of mid-low tier players together
            %{103 => %{rating: 20}, 104 => %{rating: 17}, 105 => %{rating: 13.5}},

            # A smaller bunch of even lower tier players
            %{106 => %{rating: 15}, 107 => %{rating: 7.5}},

            # Other players, a range of ratings
            %{108 => %{rating: 31}},
            %{109 => %{rating: 26}},
            %{110 => %{rating: 25}},
            %{111 => %{rating: 21}},
            %{112 => %{rating: 19}},
            %{113 => %{rating: 16}},
            %{114 => %{rating: 16}},
            %{115 => %{rating: 14}},
            %{116 => %{rating: 8}}
          ],
          2,
          algorithm: algorithm_name
        )

      assert result != nil
    end)
  end
end
