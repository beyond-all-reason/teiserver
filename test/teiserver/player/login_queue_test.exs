defmodule Teiserver.Player.LoginQueueTest do
  alias Teiserver.Player.LoginQueue

  use Teiserver.DataCase, async: false

  import Teiserver.TeiserverTestLib, only: [new_user: 0]

  @moduletag :tachyon

  setup _context do
    Teiserver.Tachyon.System.restart()
    LoginQueue.set_tick_period(:infinity)
    :ok
  end

  test "admits immediately when there is capacity" do
    user = new_user()
    set_capacity(1)
    assert LoginQueue.attempt_login(user.id) == true
    refute_receive :login_accepted, 10
  end

  test "queues when at capacity" do
    user = new_user()
    set_capacity(0)
    assert LoginQueue.attempt_login(user.id) == false
    assert LoginQueue.get_queue_length() == 1
    refute_receive :login_accepted, 10
  end

  test "admits queued player when limit is raised" do
    user = new_user()
    set_capacity(0)
    assert LoginQueue.attempt_login(user.id) == false

    set_capacity(1)
    LoginQueue.tick()
    assert_receive :login_accepted, 100
  end

  test "admits queued player on tick after capacity frees up" do
    user1 = new_user()
    user2 = new_user()

    set_capacity(1)
    assert LoginQueue.attempt_login(user1.id) == true

    set_capacity(0)
    p2 = fake_conn(:p2)
    assert LoginQueue.attempt_login(user2.id, p2) == false

    set_capacity(1)
    LoginQueue.tick()
    assert_receive {:p2, :login_accepted}, 100
  end

  test "skips disconnected waiting players without consuming a slot" do
    user1 = new_user()
    user2 = new_user()

    set_capacity(0)
    p1 = fake_conn(:p1)
    assert LoginQueue.attempt_login(user1.id, p1) == false
    assert LoginQueue.attempt_login(user2.id) == false

    kill_and_wait(p1)

    set_capacity(1)
    LoginQueue.tick()
    assert_receive :login_accepted, 100
    refute_receive :login_accepted, 10
  end

  test "drains queue in FIFO order" do
    user1 = new_user()
    user2 = new_user()
    user3 = new_user()

    set_capacity(0)
    p1 = fake_conn(:p1)
    p2 = fake_conn(:p2)
    assert LoginQueue.attempt_login(user1.id, p1) == false
    assert LoginQueue.attempt_login(user2.id, p2) == false
    assert LoginQueue.attempt_login(user3.id) == false

    set_capacity(1)
    LoginQueue.tick()
    assert_receive {:p1, :login_accepted}, 100

    set_capacity(1)
    LoginQueue.tick()
    assert_receive {:p2, :login_accepted}, 100

    refute_receive :login_accepted, 10
  end

  test "single tick dequeues multiple players at once" do
    user1 = new_user()
    user2 = new_user()
    user3 = new_user()

    set_capacity(0)
    p1 = fake_conn(:p1)
    p2 = fake_conn(:p2)
    assert LoginQueue.attempt_login(user1.id, p1) == false
    assert LoginQueue.attempt_login(user2.id, p2) == false
    assert LoginQueue.attempt_login(user3.id) == false

    set_capacity(3)
    LoginQueue.tick()

    assert_receive {:p1, :login_accepted}, 100
    assert_receive {:p2, :login_accepted}, 100
    assert_receive :login_accepted, 100
    assert LoginQueue.get_queue_length() == 0
  end

  test "tick on empty queue does nothing" do
    set_capacity(1)
    LoginQueue.tick()
    assert LoginQueue.get_queue_length() == 0
  end

  defp set_capacity(n) do
    LoginQueue.set_limit(n)
  end

  defp fake_conn(tag) do
    parent = self()
    spawn_link(fn -> fake_conn_loop(parent, tag) end)
  end

  defp fake_conn_loop(parent, tag) do
    receive do
      msg ->
        send(parent, {tag, msg})
        fake_conn_loop(parent, tag)
    end
  end

  defp kill_and_wait(pid) do
    ref = Process.monitor(pid)
    Process.unlink(pid)
    Process.exit(pid, :kill)
    assert_receive {:DOWN, ^ref, :process, _, _}
  end
end
