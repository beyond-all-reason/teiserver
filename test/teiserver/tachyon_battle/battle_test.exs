defmodule Teiserver.TachyonBattle.BattleTest do
  alias ExUnit.Callbacks
  alias Teiserver.Autohost
  alias Teiserver.Autohost.Session
  alias Teiserver.Autohost.SessionRegistry
  alias Teiserver.BotFixtures
  alias Teiserver.TachyonBattle, as: Battle
  alias Teiserver.TachyonBattle.Battle, as: BattleProcess
  use Teiserver.DataCase
  import Teiserver.Support.Polling, only: [poll_until_some: 1]

  @moduletag :tachyon

  describe "start battle" do
    test "happy path" do
      autohost_id = :rand.uniform(10_000_000)
      match_id = :rand.uniform(10_000_000)
      SessionRegistry.register(%{id: autohost_id})

      {:ok, battle_id, _pid} =
        Battle.start_battle_process(autohost_id, match_id, BotFixtures.start_script())

      poll_until_some(fn -> Battle.lookup(battle_id) end)
    end
  end

  describe "send message" do
    test "autohost is there" do
      battle_id = to_string(UUID.uuid4())
      match_id = :rand.uniform(10_000_000)
      autohost_id = :rand.uniform(10_000_000)

      autohost_sess_pid =
        {%{id: autohost_id}, self()}
        |> Session.child_spec()
        |> Callbacks.start_link_supervised!()

      Session.update_capacity(autohost_sess_pid, 10, 0)

      assert_receive {:call_client, "autohost/subscribeUpdates", _, ref}
      send(ref, {ref, %{"status" => "success"}})

      start_script = BotFixtures.start_script()

      {:ok, _battle_pid} =
        BattleProcess.start_link(%{
          battle_id: battle_id,
          match_id: match_id,
          autohost_id: autohost_id,
          start_script: start_script
        })

      pid = self()

      start_task =
        Task.async(fn ->
          Autohost.start_battle(autohost_id, battle_id, pid, start_script)
        end)

      assert_receive {:start_battle, ^battle_id, _start_script}

      Session.reply_start_battle(
        autohost_sess_pid,
        battle_id,
        {:ok, %{ips: ["1.2.3.4"], port: 1234}}
      )

      task = Task.async(fn -> Battle.send_message(battle_id, "hello") end)

      assert_receive {:send_message, ref, %{battle_id: ^battle_id, message: "hello"}}

      Task.await(start_task)

      Session.reply_send_message(autohost_sess_pid, ref, :ok)
      assert Task.await(task) == :ok
    end
  end

  test "kill battle" do
    battle_id = to_string(UUID.uuid4())
    match_id = :rand.uniform(10_000_000)
    autohost_id = :rand.uniform(10_000_000)
    SessionRegistry.register(%{id: autohost_id})

    {:ok, _battle_pid} =
      BattleProcess.start_link(%{
        battle_id: battle_id,
        match_id: match_id,
        autohost_id: autohost_id,
        start_script: BotFixtures.start_script()
      })

    task = Task.async(fn -> Battle.kill(battle_id) end)
    assert_receive {:"$gen_call", reply_to, {:kill_battle, ^battle_id}}
    resp = %{ips: ["1.2.3.4"], port: 1234}
    GenServer.reply(reply_to, {:ok, resp})

    assert Task.await(task) == {:ok, resp}
  end
end
