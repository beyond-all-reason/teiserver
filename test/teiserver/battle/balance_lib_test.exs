defmodule Teiserver.Battle.BalanceLibTest do
  @moduledoc false
  use Teiserver.DataCase, async: true
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
            %{1 => 5}
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
            %{1 => 5},
            %{2 => 6},
            %{3 => 7},
            %{4 => 8}
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
            %{1 => 5},
            %{2 => 6},
            %{3 => 7},
            %{4 => 8}
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
            %{1 => 5},
            %{2 => 6},
            %{3 => 7},
            %{4 => 8},
            %{5 => 9},
            %{6 => 9}
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
            %{101 => 41, 102 => 35},

            # A bunch of mid-low tier players together
            %{103 => 20, 104 => 17, 105 => 13.5},

            # A smaller bunch of even lower tier players
            %{106 => 15, 107 => 7.5},

            # Other players, a range of ratings
            %{108 => 31},
            %{109 => 26},
            %{110 => 25},
            %{111 => 21},
            %{112 => 19},
            %{113 => 16},
            %{114 => 16},
            %{115 => 14},
            %{116 => 8}
          ],
          2,
          algorithm: algorithm_name
        )

      assert result != nil
    end)
  end
end
