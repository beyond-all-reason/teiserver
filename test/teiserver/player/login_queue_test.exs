defmodule Teiserver.Player.LoginQueueTest do
  alias Teiserver.Player
  alias Teiserver.Player.LoginQueue

  use Teiserver.DataCase, async: false

  import Teiserver.TeiserverTestLib, only: [new_user: 0]

  @moduletag :tachyon

  setup _context do
    :ok = Supervisor.terminate_child(Teiserver.Player.System, LoginQueue)
    {:ok, _pid} = Supervisor.restart_child(Teiserver.Player.System, LoginQueue)
    LoginQueue.set_tick_period(:infinity)
    :ok
  end

  test "admits immediately when there is capacity" do
    user = new_user()
    set_capacity(1)
    assert LoginQueue.attempt_login(self(), user.id) == true
    refute_receive {:login_accepted, _}, 10
  end

  test "queues when at capacity" do
    user = new_user()
    set_capacity(0)
    assert LoginQueue.attempt_login(self(), user.id) == false
    assert LoginQueue.get_queue_length() == 1
    refute_receive {:login_accepted, _}, 10
  end

  test "admits queued player when limit is raised" do
    user = new_user()
    set_capacity(0)
    assert LoginQueue.attempt_login(self(), user.id) == false

    set_capacity(1)
    LoginQueue.tick()
    assert_receive {:login_accepted, id}, 100
    assert id == user.id
  end

  test "admits queued player on tick after capacity frees up" do
    user1 = new_user()
    user2 = new_user()

    set_capacity(1)
    assert LoginQueue.attempt_login(self(), user1.id) == true

    set_capacity(0)
    p2 = fake_conn()
    assert LoginQueue.attempt_login(p2, user2.id) == false

    set_capacity(1)
    LoginQueue.tick()
    assert_receive {:login_accepted, id}, 100
    assert id == user2.id
  end

  test "skips disconnected waiting players without consuming a slot" do
    user1 = new_user()
    user2 = new_user()

    set_capacity(0)
    p1 = fake_conn()
    assert LoginQueue.attempt_login(p1, user1.id) == false
    assert LoginQueue.attempt_login(self(), user2.id) == false

    kill_and_wait(p1)

    set_capacity(1)
    LoginQueue.tick()
    assert_receive {:login_accepted, id}, 100
    assert id == user2.id
    refute_receive {:login_accepted, _}, 10
  end

  test "drains queue in FIFO order" do
    user1 = new_user()
    user2 = new_user()
    user3 = new_user()

    set_capacity(0)
    p1 = fake_conn()
    p2 = fake_conn()
    assert LoginQueue.attempt_login(p1, user1.id) == false
    assert LoginQueue.attempt_login(p2, user2.id) == false
    assert LoginQueue.attempt_login(self(), user3.id) == false

    set_capacity(1)
    LoginQueue.tick()
    assert_receive {:login_accepted, id}, 100
    assert id == user1.id

    set_capacity(1)
    LoginQueue.tick()
    assert_receive {:login_accepted, id}, 100
    assert id == user2.id

    refute_receive {:login_accepted, _}, 10
  end

  test "single tick dequeues multiple players at once" do
    user1 = new_user()
    user2 = new_user()
    user3 = new_user()

    set_capacity(0)
    p1 = fake_conn()
    p2 = fake_conn()
    assert LoginQueue.attempt_login(p1, user1.id) == false
    assert LoginQueue.attempt_login(p2, user2.id) == false
    assert LoginQueue.attempt_login(self(), user3.id) == false

    set_capacity(3)
    LoginQueue.tick()

    assert_receive {:login_accepted, id1}, 100
    assert_receive {:login_accepted, id2}, 100
    assert_receive {:login_accepted, id3}, 100
    assert Enum.sort([id1, id2, id3]) == Enum.sort([user1.id, user2.id, user3.id])
    assert LoginQueue.get_queue_length() == 0
  end

  test "tick on empty queue does nothing" do
    set_capacity(1)
    LoginQueue.tick()
    assert LoginQueue.get_queue_length() == 0
  end

  defp set_capacity(n) do
    LoginQueue.set_limit(Player.Registry.connected_count() + n)
  end

  defp fake_conn do
    parent = self()
    spawn(fn -> fake_conn_loop(parent) end)
  end

  defp fake_conn_loop(parent) do
    receive do
      msg ->
        send(parent, msg)
        fake_conn_loop(parent)
    end
  end

  defp kill_and_wait(pid) do
    ref = Process.monitor(pid)
    Process.exit(pid, :kill)
    assert_receive {:DOWN, ^ref, :process, _, _}
  end
end
