defmodule Teiserver.Account.LoginThrottleServerTest do
  @moduledoc false

  use Teiserver.DataCase, async: false
  alias Teiserver.Config
  alias Teiserver.Account
  alias Teiserver.Account.LoginThrottleServer

  import Teiserver.TeiserverTestLib,
    only: [
      new_user: 0
    ]

  setup _ctx do
    LoginThrottleServer.restart()
    :ok = Supervisor.terminate_child(Teiserver.Supervisor, Teiserver.ClientRegistry)
    Supervisor.restart_child(Teiserver.Supervisor, Teiserver.ClientRegistry)

    LoginThrottleServer.set_tick_period(:infinity)
    # ensure the rate limiter doesn't interfere with any tests
    LoginThrottleServer.reset_rate_limiter(1000, true)
  end

  test "can stop user from login" do
    set_capacity(0)
    user = new_user()
    assert LoginThrottleServer.attempt_login(self(), user.id) == false
    refute_receive {:login_accepted, _}, 5
  end

  test "bots ignore limits" do
    set_capacity(0)
    bot = new_user()
    bot_id = bot.id
    Account.update_cache_user(bot.id, %{roles: ["Bot"]})
    assert LoginThrottleServer.attempt_login(self(), bot_id) == true
  end

  test "can immediately log in when there is capacity" do
    set_capacity(1)
    user = new_user()
    assert LoginThrottleServer.attempt_login(self(), user.id) == true
  end

  test "can login when capacity becomes available" do
    set_capacity(0)
    user = new_user()
    assert LoginThrottleServer.attempt_login(self(), user.id) == false
    assert LoginThrottleServer.get_queue_length() == 1
    set_capacity(1)
    LoginThrottleServer.tick()
    assert_receive {:login_accepted, _}, 5
  end

  test "works with many players" do
    set_capacity(0)

    {user1, t1} = {new_user(), oneshot_pid()}
    {user2, t2} = {new_user(), oneshot_pid()}
    user3 = new_user()

    assert LoginThrottleServer.attempt_login(t1.pid, user1.id) == false
    assert LoginThrottleServer.attempt_login(t2.pid, user2.id) == false
    assert LoginThrottleServer.attempt_login(self(), user3.id) == false
    assert LoginThrottleServer.get_queue_length() == 3

    set_capacity(2)
    LoginThrottleServer.tick()

    assert_receive {:login_accepted, id1}, 5
    assert_receive {:login_accepted, id2}, 5
    # the messages are coming from tasks, so their order depends on the scheduler
    assert MapSet.new([id1, id2]) == MapSet.new([user1.id, user2.id])
    refute_receive {:login_accepted, _}, 5
  end

  test "ignore players that have disconnected" do
    set_capacity(0)
    {user1, t1} = {new_user(), oneshot_pid()}
    user2 = new_user()

    assert LoginThrottleServer.attempt_login(t1.pid, user1.id) == false
    assert LoginThrottleServer.attempt_login(self(), user2.id) == false
    assert LoginThrottleServer.get_queue_length() == 2

    set_capacity(1)
    send(t1.pid, nil)
    Task.await(t1)
    # now, t1 is dead

    # members aren't cleaned up when DOWN is received
    assert LoginThrottleServer.get_queue_length() == 2

    # attempt to aleviate a potential race, where the DOWN message from the
    # task reach the throttling server too late
    :timer.sleep(5)
    LoginThrottleServer.tick()

    assert_receive {:login_accepted, id}, 5
    assert user2.id == id
  end

  test "respect rate limiter" do
    set_capacity(0)
    LoginThrottleServer.reset_rate_limiter(1)
    {user1, t1} = {new_user(), oneshot_pid()}
    user2 = new_user()

    assert LoginThrottleServer.attempt_login(t1.pid, user1.id) == false
    assert LoginThrottleServer.attempt_login(self(), user2.id) == false
    assert LoginThrottleServer.get_queue_length() == 2

    set_capacity(2)
    LoginThrottleServer.tick()

    assert_receive {:login_accepted, id}, 5
    assert id == user1.id
    refute_receive {:login_accepted, _}, 5
    assert LoginThrottleServer.get_queue_length() == 1
  end

  defp set_capacity(n) do
    Config.update_site_config("system.User limit", n)
  end

  defp oneshot_pid() do
    parent = self()

    Task.async(fn ->
      receive do
        x -> send(parent, x)
      end
    end)
  end
end
