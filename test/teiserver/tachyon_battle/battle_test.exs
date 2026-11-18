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

      assert_receive {:send_message, cb_state, %{battle_id: ^battle_id, message: "hello"}}
      Session.async_reply(autohost_pid, cb_state, :ok)
      Task.await(msg_task)
    end
  end

  test "kill battle" do
    %{battle_id: battle_id, autohost_pid: autohost_pid} = setup_autohost_and_battle()

    task = Task.async(fn -> Battle.kill(battle_id) end)
    assert_receive {:kill_battle, cb_state, ^battle_id}
    Session.async_reply(autohost_pid, cb_state, :ok)
    assert Task.await(task) == :ok
  end

  test "add player" do
    %{battle_id: battle_id, autohost_pid: autohost_pid} = setup_autohost_and_battle()
    task = Task.async(fn -> Battle.add_player(battle_id, 12345, "playername", "hunter2") end)

    assert_receive {:add_player, cb_state,
                    %{
                      name: "playername",
                      user_id: 12345,
                      password: "hunter2",
                      battle_id: ^battle_id
                    }}

    Session.async_reply(autohost_pid, cb_state, :ok)
    {:ok, %{port: _port, ips: _ips}} = Task.await(task)

    re_add = Task.async(fn -> Battle.add_player(battle_id, 12345, "playername", "hunter2") end)
    # battle should remember players added after the start as well
    {:ok, %{port: _port, ips: _ips, password: "hunter2"}} = Task.await(re_add, 100)
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
          Battle.add_player(battle_id, 10000 + i, "playername#{i}", "hunter#{i}")
        end)
      end)

    Enum.each(1..players_to_add, fn _i ->
      assert_receive {:add_player, cb_state, _}
      Session.async_reply(autohost_pid, cb_state, :ok)
    end)

    Task.await_many(add_tasks)

    # now we're at capacity
    {:error, :capacity_reached} =
      Battle.add_player(battle_id, 99999, "too_many_ticks", "ticktick")
  end

  describe "participant roles" do
    test "players from start script are players" do
      %{battle_id: battle_id, start_script: start_script} = setup_autohost_and_battle()

      player =
        start_script.ally_teams |> hd() |> Map.get(:teams) |> hd() |> Map.get(:players) |> hd()

      assert %{role: :player} = participants(battle_id)[player.user_id]
    end

    test "late joiners are spectators" do
      %{battle_id: battle_id, autohost_pid: autohost_pid} = setup_autohost_and_battle()
      task = Task.async(fn -> Battle.add_player(battle_id, 12345, "latecomer", "pw") end)
      assert_receive {:add_player, cb_state, _}
      Session.async_reply(autohost_pid, cb_state, :ok)
      {:ok, _connection} = Task.await(task)

      assert %{role: :spectator} = participants(battle_id)[12345]
    end

    test "player_left event does not crash the battle" do
      %{battle_id: battle_id, start_script: start_script} = setup_autohost_and_battle()

      player =
        start_script.ally_teams |> hd() |> Map.get(:teams) |> hd() |> Map.get(:players) |> hd()

      pid = Teiserver.TachyonBattle.Registry.lookup(battle_id)

      Battle.send_update_event(%{
        battle_id: battle_id,
        time: DateTime.utc_now(),
        update: {:player_left, %{user_id: player.user_id, reason: :left}}
      })

      assert :sys.get_state(pid)
      assert Process.alive?(pid)
    end
  end

  defp participants(battle_id) do
    battle_id
    |> Teiserver.TachyonBattle.Registry.lookup()
    |> :sys.get_state()
    |> Map.fetch!(:participants)
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

    assert_receive {:start_battle, battle_id, start_script, cb_state}
    resp = %{ips: ["1.2.3.4"], port: 12345}
    Session.async_reply(autohost_pid, cb_state, {:ok, resp})
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
