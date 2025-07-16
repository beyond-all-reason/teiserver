defmodule Teiserver.TachyonBattle.BattleTest do
  use Teiserver.DataCase
  import Teiserver.Support.Polling, only: [poll_until_some: 1]
  alias Teiserver.TachyonBattle, as: Battle

  @moduletag :tachyon

  describe "start battle" do
    test "happy path" do
      autohost_id = 123
      Teiserver.Autohost.Registry.register(%{id: autohost_id})
      {:ok, battle_id, _pid} = Battle.start_battle(autohost_id)
      poll_until_some(fn -> Battle.lookup(battle_id) end)
    end
  end

  describe "send message" do
    test "autohost is there" do
      battle_id = to_string(UUID.uuid4())
      autohost_id = :rand.uniform(1..10000000)
      Teiserver.Autohost.Registry.register(%{id: autohost_id})

      {:ok, _battle_pid} =
        Battle.Battle.start_link(%{battle_id: battle_id, autohost_id: autohost_id})

      task = Task.async(fn -> Battle.send_message(battle_id, "hello") end)

      assert_receive {:call_client, "autohost/sendMessage",
                      %{battleId: ^battle_id, message: "hello"}, from}

      send(from, {from, %{"status" => "success"}})
      assert Task.await(task) == :ok
    end
  end
end
