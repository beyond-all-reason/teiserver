defmodule Teiserver.Game.BalancerServerTest do
  @moduledoc false
  use ExUnit.Case
  @moduletag :balance_test
  alias Teiserver.Game.BalancerServer

  test "get fuzz multiplier" do
    result = BalancerServer.get_fuzz_multiplier([])
    assert result == 0

    result = BalancerServer.get_fuzz_multiplier(algorithm: "loser_picks", fuzz_multiplier: 0.5)
    assert result == 0.5

    result =
      BalancerServer.get_fuzz_multiplier(algorithm: "split_one_chevs", fuzz_multiplier: 0.5)

    assert result == 0
  end
end
