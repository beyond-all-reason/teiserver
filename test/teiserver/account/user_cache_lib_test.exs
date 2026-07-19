defmodule Teiserver.Account.UserCacheLibTest do
  @moduledoc """
      get_username(id)           holds :users[id], wants :users_lookup_id_with_name[name]
      get_userid_from_name(name) holds :users_lookup_id_with_name[name], wants :users[id]
  """
  use Teiserver.DataCase, async: false

  alias Teiserver.Account
  alias Teiserver.Account.UserCacheLib

  import Teiserver.AccountFixtures, only: [user_fixture: 0]

  # let the deadlock actually fire, con_cache gives up after acquire_lock_timeout (default 5s)
  @await 10_000

  # it's a race condition so we need to run multiple attempts
  # each round takes ms if the deadlock is fixed
  @rounds 50

  # catch the lock timeout so it can't take the whole process down with it
  defp lookup(fun) do
    Task.async(fn ->
      try do
        fun.()
        :ok
      catch
        :exit, {:timeout, {GenServer, :call, [_pid, {:lock, key, _ref}, timeout]}} ->
          {:deadlock, key, timeout}
      end
    end)
  end

  describe "concurrent cache population" do
    test "get_username/1 and get_userid_from_name/1 do not deadlock against each other" do
      user = user_fixture()

      for round <- 1..@rounds do
        # make sure both paths start cold
        UserCacheLib.decache_user(user.id)

        tasks = [
          lookup(fn -> Account.get_username(user.id) end),
          lookup(fn -> Account.get_userid_from_name(user.name) end)
        ]

        deadlocks =
          tasks
          |> Task.yield_many(@await)
          |> Enum.flat_map(fn
            {_task, {:ok, {:deadlock, key, timeout}}} -> [{key, timeout}]
            # never returned even after the lock timeout should have fired
            {_task, nil} -> [{:no_result, @await}]
            {_task, _} -> []
          end)

        # tear the round down before asserting, so a failure doesn't leave
        # lock-holding processes behind to poison later tests
        Enum.each(tasks, &Task.shutdown(&1, :brutal_kill))

        assert deadlocks == [],
               """
               Deadlock on round #{round}:
               #{Enum.map_join(deadlocks, "\n", fn {key, t} -> "  waited #{t}ms for lock on key #{inspect(key)}" end)}
               """
      end

      # sanity check
      assert Account.get_username(user.id) == user.name
      assert Account.get_userid_from_name(user.name) == user.id

      UserCacheLib.decache_user(user.id)
    end
  end
end
