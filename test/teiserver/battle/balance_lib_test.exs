defmodule Teiserver.Battle.BalanceLibTest do
  use Central.DataCase, async: true
  alias Teiserver.Battle.BalanceLib

  test "balance algorithms" do
    # We don't care about the result, just that they don't error
    BalanceLib.algorithm_modules()
      |> Map.keys()
      |> Enum.each(fn algorithm_name ->
        result = BalanceLib.create_balance(
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
end
