defmodule Teiserver.TachyonBattle.BattleTest do
  use Teiserver.DataCase
  import Teiserver.Support.Polling, only: [poll_until_some: 1]
  alias Teiserver.TachyonBattle, as: Battle
  alias Teiserver.Autohost

  @moduletag :tachyon

  describe "start battle" do
    @tag :skip
    test "happy path" do
      autohost_id = :rand.uniform(10_000_000)
      match_id = :rand.uniform(10_000_000)
      Autohost.SessionRegistry.register(%{id: autohost_id})
      {:ok, battle_id, _pid} = Battle.start_battle_process(autohost_id, match_id)
      poll_until_some(fn -> Battle.lookup(battle_id) end)
    end
  end

  describe "send message" do
    @tag :skip
    test "autohost is there" do
      battle_id = to_string(UUID.uuid4())
      match_id = :rand.uniform(10_000_000)
      autohost_id = :rand.uniform(10_000_000)
      Autohost.SessionRegistry.register(%{id: autohost_id})

      {:ok, _battle_pid} =
        Battle.Battle.start_link(%{
          battle_id: battle_id,
          match_id: match_id,
          autohost_id: autohost_id
        })

      task = Task.async(fn -> Battle.send_message(battle_id, "hello") end)

      assert_receive {:call_client, "autohost/sendMessage",
                      %{battleId: ^battle_id, message: "hello"}, from}

      send(from, {from, %{"status" => "success"}})
      assert Task.await(task) == :ok
    end
  end

  @tag :skip
  test "kill battle" do
    battle_id = to_string(UUID.uuid4())
    match_id = :rand.uniform(10_000_000)
    autohost_id = :rand.uniform(10_000_000)
    Autohost.SessionRegistry.register(%{id: autohost_id})

    {:ok, _battle_pid} =
      Battle.Battle.start_link(%{
        battle_id: battle_id,
        match_id: match_id,
        autohost_id: autohost_id
      })

    task = Task.async(fn -> Battle.kill(battle_id) end)
    assert_receive {:call_client, "autohost/kill", %{battleId: ^battle_id}, from}
    resp = %{"status" => "success"}
    send(from, {from, resp})
    assert Task.await(task) == :ok
  end
end
