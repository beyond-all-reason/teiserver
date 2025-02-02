defmodule Teiserver.TachyonBattle.BattleTest do
  use Teiserver.DataCase, async: true
  import Teiserver.Support.Tachyon, only: [poll_until_some: 1]
  alias Teiserver.TachyonBattle, as: Battle

  describe "start battle" do
    test "happy path" do
      {:ok, battle_id} = Battle.start_battle("irrelevant_autohost_id")
      poll_until_some(fn -> Battle.lookup(battle_id) end)
    end
  end
end
