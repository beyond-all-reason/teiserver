defmodule Teiserver.Account.LoginThrottleServerTest do
  @moduledoc false

  alias Teiserver.Account
  alias Teiserver.Account.Auth
  alias Teiserver.Account.LoginThrottleServer
  alias Teiserver.Config
  use Teiserver.DataCase, async: false

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
    user = new_user()
    set_capacity(0)
    assert LoginThrottleServer.attempt_login(self(), user.id) == false
    refute_receive {:login_accepted, _}, 5
  end

  test "bots ignore limits" do
    bot = new_user()
    bot_id = bot.id
    Auth.add_roles(bot.id, ["Bot"])
    set_capacity(0)
    assert LoginThrottleServer.attempt_login(self(), bot_id) == true
  end

  test "can immediately log in when there is capacity" do
    user = new_user()
    set_capacity(1)
    assert LoginThrottleServer.attempt_login(self(), user.id) == true
  end

  test "can login when capacity becomes available" do
    user = new_user()
    set_capacity(0)
    assert LoginThrottleServer.attempt_login(self(), user.id) == false
    assert LoginThrottleServer.get_queue_length() == 1
    set_capacity(1)
    LoginThrottleServer.tick()
    assert_receive {:login_accepted, _}, 5
  end

  test "works with many players" do
    {user1, t1} = {new_user(), oneshot_pid()}
    {user2, t2} = {new_user(), oneshot_pid()}
    user3 = new_user()

    set_capacity(0)
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

  test "skips a client that disconnects while the login queue is paused" do
    {user1, t1} = {new_user(), oneshot_pid()}
    %{id: id} = new_user()

    set_capacity(1)
    LoginThrottleServer.reset_rate_limiter(0)
    refute LoginThrottleServer.attempt_login(t1.pid, user1.id)
    LoginThrottleServer.tick()
    refute LoginThrottleServer.attempt_login(self(), id)

    Task.shutdown(t1, :brutal_kill)

    LoginThrottleServer.reset_rate_limiter(1, true)
    LoginThrottleServer.tick()
    assert_receive {:login_accepted, ^id}
  end

  test "a zero login rate pauses the queue until a positive rate is set" do
    key = "system.Login rate"
    previous_rate = Config.get_site_config_cache(key)

    on_exit(fn ->
      Teiserver.cache_delete(:config_site_cache, key)
      LoginThrottleServer.reset_rate_limiter(previous_rate)
    end)

    assert :ok = Config.update_site_config(key, "0")
    Teiserver.cache_delete(:config_site_cache, key)
    assert {:ok, _pid} = LoginThrottleServer.restart()
    assert :ok = LoginThrottleServer.set_tick_period(:infinity)
    set_capacity(1)
    %{id: id} = new_user()
    refute LoginThrottleServer.attempt_login(self(), id)

    assert :ok = LoginThrottleServer.reset_rate_limiter(0, true)
    LoginThrottleServer.tick()
    refute_receive {:login_accepted, ^id}

    for invalid <- ["-1", "-0.5", "1.5x", "unknown", ""] do
      assert {:error, _changeset} = Config.update_site_config(key, invalid)
    end

    assert Config.get_site_config_val(key) == 0
    assert_raise FunctionClauseError, fn -> LoginThrottleServer.reset_rate_limiter(-1) end
    assert :ok = Config.update_site_config(key, "0.5")
    LoginThrottleServer.set_tick_period(10)
    assert_receive {:login_accepted, ^id}
  end

  test "respect rate limiter" do
    LoginThrottleServer.reset_rate_limiter(1, true)
    {user1, t1} = {new_user(), oneshot_pid()}
    user2 = new_user()

    set_capacity(0)
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

  test "respect rate limiter even when there is capacity" do
    LoginThrottleServer.reset_rate_limiter(1, false)
    {user1, t1} = {new_user(), oneshot_pid()}
    {user2, t2} = {new_user(), oneshot_pid()}

    bot = new_user()
    Auth.add_roles(bot.id, ["Bot"])

    set_capacity(100)
    assert LoginThrottleServer.attempt_login(t1.pid, user1.id) == true
    assert LoginThrottleServer.attempt_login(t2.pid, user2.id) == false
    assert LoginThrottleServer.get_queue_length() == 1

    # bots do ignore rate limits
    assert LoginThrottleServer.attempt_login(self(), bot.id) == true
  end

  defp set_capacity(n) do
    # this is a hack because there seems to be some flakyness with `count_client`
    # from other tests
    current_count = Account.count_non_bot_clients()
    LoginThrottleServer.set_login_limit(current_count + n)
  end

  defp oneshot_pid do
    parent = self()

    Task.async(fn ->
      receive do
        x -> send(parent, x)
      end
    end)
  end
end
