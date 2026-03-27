defmodule Teiserver.TachyonBattle.BattleTest do
  alias Teiserver.Autohost.Session
  alias Teiserver.Autohost.SessionSupervisor
  alias Teiserver.BotFixtures
  alias Teiserver.TachyonBattle, as: Battle
  use Teiserver.DataCase
  import Teiserver.Support.Polling, only: [poll_until_some: 1]

  @moduletag :tachyon

  describe "start battle" do
    test "happy path" do
      %{battle_id: battle_id} = setup_autohost_and_battle()

      poll_until_some(fn -> Battle.lookup(battle_id) end)
    end
  end

  describe "send message" do
    test "autohost is there" do
      %{battle_id: battle_id, autohost_pid: autohost_pid} = setup_autohost_and_battle()
      msg_task = Task.async(fn -> Battle.send_message(battle_id, "hello") end)

      assert_receive {:send_message, ref, %{battle_id: ^battle_id, message: "hello"}}
      Session.reply_send_message(autohost_pid, ref, :ok)
      Task.await(msg_task)
    end
  end

  test "kill battle" do
    %{battle_id: battle_id, autohost_pid: autohost_pid} = setup_autohost_and_battle()

    task = Task.async(fn -> Battle.kill(battle_id) end)
    assert_receive {:kill_battle, ref, ^battle_id}
    Session.reply_kill_battle(autohost_pid, ref, :ok)
    assert Task.await(task) == :ok
  end

  test "add player" do
    %{battle_id: battle_id, autohost_pid: autohost_pid} = setup_autohost_and_battle()
    task = Task.async(fn -> Battle.add_player(battle_id, 12345, "playername", "hunter2") end)

    assert_receive {:add_player, ref,
                    %{
                      name: "playername",
                      user_id: 12345,
                      password: "hunter2",
                      battle_id: ^battle_id
                    }}

    Session.reply_add_player(autohost_pid, ref, :ok)
    {:ok, %{port: _port, ips: _ips}} = Task.await(task)

    re_add = Task.async(fn -> Battle.add_player(battle_id, 12345, "playername", "hunter2") end)
    # battle should remember players added after the start as well
    {:ok, %{port: _port, ips: _ips}} = Task.await(re_add, 100)
  end

  test "remember players from start script" do
    %{battle_id: battle_id, start_script: start_script} = setup_autohost_and_battle()

    player =
      start_script
      |> Map.get(:ally_teams)
      |> hd()
      |> Map.get(:teams)
      |> hd()
      |> Map.get(:players)
      |> hd()

    task =
      Task.async(fn ->
        Battle.add_player(battle_id, player.user_id, player.name, player.password)
      end)

    # no message to autohost should be required
    {:ok, %{port: _port, ips: _ips}} = Task.await(task, 100)
  end

  test "has maximum capacity" do
    # SETUP
    %{battle_id: battle_id, autohost_pid: autohost_pid} = setup_autohost_and_battle()
    players_to_add = 253

    add_tasks =
      Enum.map(1..players_to_add, fn i ->
        Task.async(fn ->
          Battle.add_player(battle_id, 10000 + i, "playername#{i}", "hunted#{i}")
        end)
      end)

    Enum.each(1..players_to_add, fn _i ->
      assert_receive {:add_player, ref, _}
      Session.reply_add_player(autohost_pid, ref, :ok)
    end)

    Task.await_many(add_tasks)

    # now we're at capacity
    {:error, :capacity_reached} =
      Battle.add_player(battle_id, 99999, "too_many_ticks", "ticktick")
  end

  # setup a handshaked autohost with some defaults
  defp setup_autohost_and_battle do
    match_id = :rand.uniform(10_000_000)
    autohost_id = :rand.uniform(10_000_000)

    {:ok, autohost_pid} = SessionSupervisor.start_session(%{id: autohost_id}, self())

    receive do
      {:call_client, "autohost/subscribeUpdates", _payload, ref} ->
        send(ref, {ref, %{"status" => "success"}})
    end

    send(autohost_pid, {:update_capacity, 10, 0})

    start_task =
      Task.async(fn ->
        {:ok, _battle_id, _pid} =
          Battle.start_battle_process(autohost_id, match_id, BotFixtures.start_script())
      end)

    assert_receive {:start_battle, battle_id, start_script}
    resp = %{ips: ["1.2.3.4"], port: 12345}
    Session.reply_start_battle(autohost_pid, battle_id, {:ok, resp})
    Task.await(start_task)

    %{
      match_id: match_id,
      autohost_id: autohost_id,
      autohost_pid: autohost_pid,
      battle_id: battle_id,
      start_script: start_script
    }
  end
end
