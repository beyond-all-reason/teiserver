defmodule Teiserver.TachyonBattle.BattleTest do
  use Teiserver.DataCase
  import Teiserver.Support.Polling, only: [poll_until_some: 1]
  alias Teiserver.TachyonBattle, as: Battle

  setup do
    ExUnit.Callbacks.start_supervised!(Teiserver.Tachyon.System)
    :ok
  end

  describe "start battle" do
    test "happy path" do
      autohost_id = 123
      Teiserver.Autohost.Registry.register(%{id: autohost_id})
      {:ok, battle_id} = Battle.start_battle(autohost_id)
      poll_until_some(fn -> Battle.lookup(battle_id) end)
    end
  end
end
