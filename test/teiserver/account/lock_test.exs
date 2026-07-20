defmodule Teiserver.Account.UserCacheLibTest do
  alias Teiserver.Account
  alias Teiserver.Account.UserCacheLib

  use Teiserver.DataCase, async: false
  import Teiserver.AccountFixtures, only: [user_fixture: 0]

  describe "deadlocks on cache population" do
    # see https://github.com/beyond-all-reason/teiserver/issues/1394
    test "get_username/1 and get_userid_from_name/1" do
      user = user_fixture()

      fns = [
        fn -> Account.get_username(user.id) end,
        fn -> Account.get_userid_from_name(user.name) end
      ]

      {deadlocks, at_round} = check_deadlocks(fn -> UserCacheLib.decache_user(user.id) end, fns)

      assert deadlocks == [], "Deadlock detected on round #{at_round}"

      # sanity check
      assert Account.get_username(user.id) == user.name
      assert Account.get_userid_from_name(user.name) == user.id
    end

    test "get_username/1 and deprecated_get_user_by_email/" do
      user = user_fixture()

      fns = [
        fn -> Account.get_username(user.id) end,
        fn -> Account.deprecated_get_user_by_email(user.email) end
      ]

      {deadlocks, at_round} = check_deadlocks(fn -> UserCacheLib.decache_user(user.id) end, fns)

      assert deadlocks == [], "Deadlock detected on round #{at_round}"

      # sanity check
      assert Account.get_username(user.id) == user.name
      assert Account.deprecated_get_user_by_email(user.email).email == user.email
    end
  end

  defp with_catch_timeout(fun) do
    Task.async(fn ->
      try do
        fun.()
        :ok
      catch
        :exit, {:timeout, _reason} -> :deadlock
      end
    end)
  end

  defp check_deadlocks(setup_round_fn, fns, rounds \\ 50) do
    # make sure both paths start cold
    setup_round_fn.()

    tasks =
      Enum.map(fns, fn f ->
        with_catch_timeout(fn -> f.() end)
      end)

    deadlocks =
      tasks
      # wait for at least as long as the default timeout for ConCache (5s)
      |> Task.yield_many(:timer.seconds(6))
      |> Enum.map(fn
        {_task, {:ok, :deadlock}} -> :deadlock
        {_task, {:ok, :ok}} -> nil
        # never returned even after the lock timeout should have fired
        {_task, nil} -> :no_result
      end)
      |> Enum.reject(&is_nil/1)

    # tear the round down before asserting, so a failure doesn't leave
    # lock-holding processes behind to poison later tests
    Enum.each(tasks, &Task.shutdown(&1, :brutal_kill))

    case {deadlocks, rounds} do
      {results, 0} ->
        {results, 0}

      {[], rounds} ->
        check_deadlocks(setup_round_fn, fns, rounds - 1)

      {results, rounds} ->
        {results, rounds}
    end
  end
end
