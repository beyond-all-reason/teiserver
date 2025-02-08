defmodule Teiserver.TachyonBattle.BattleTest do
  use Teiserver.DataCase, async: true
  import Teiserver.Support.Tachyon, only: [poll_until_some: 1]
  alias Teiserver.TachyonBattle, as: Battle

  describe "start battle" do
    test "happy path" do
      autohost_id = 123
      Teiserver.Autohost.Registry.register(%{id: autohost_id})
      on_exit(fn -> Teiserver.Autohost.Registry.unregister(autohost_id) end)
      {:ok, battle_id} = Battle.start_battle(autohost_id)
      poll_until_some(fn -> Battle.lookup(battle_id) end)
    end
  end
end
