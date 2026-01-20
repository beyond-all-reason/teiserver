defmodule Teiserver.TachyonBattle.BattleTest do
  use Teiserver.DataCase
  import Teiserver.Support.Polling, only: [poll_until_some: 1]
  alias Teiserver.TachyonBattle, as: Battle
  alias Teiserver.Autohost

  @moduletag :tachyon

  describe "start battle" do
    test "happy path" do
      autohost_id = :rand.uniform(10_000_000)
      match_id = :rand.uniform(10_000_000)
      Autohost.SessionRegistry.register(%{id: autohost_id})
      {:ok, battle_id, _pid} = Battle.start_battle_process(autohost_id, match_id)
      poll_until_some(fn -> Battle.lookup(battle_id) end)
    end
  end

  describe "send message" do
    test "autohost is there" do
      battle_id = to_string(UUID.uuid4())
      match_id = :rand.uniform(10_000_000)
      autohost_id = :rand.uniform(10_000_000)

      autohost_sess_pid =
        ExUnit.Callbacks.start_link_supervised!(
          Autohost.Session.child_spec({%{id: autohost_id}, self()})
        )

      assert_receive {:call_client, "autohost/subscribeUpdates", _, ref}
      send(ref, {ref, %{"status" => "success"}})

      {:ok, _battle_pid} =
        Battle.Battle.start_link(%{
          battle_id: battle_id,
          match_id: match_id,
          autohost_id: autohost_id
        })

      task = Task.async(fn -> Battle.send_message(battle_id, "hello") end)

      assert_receive {:send_message, ref, %{battle_id: ^battle_id, message: "hello"}}

      Autohost.Session.reply_send_message(autohost_sess_pid, ref, :ok)
      assert Task.await(task) == :ok
    end
  end

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
