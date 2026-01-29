defmodule Teiserver.Load.ConcurrentUsersLoadTest do
  @moduledoc """
  Load tests for concurrent user operations.

  These tests measure performance under load and verify the system
  can handle multiple concurrent users and operations.

  Run with: mix test test/teiserver/load/ --include load_test
  """
  use Teiserver.ServerCase

  import Teiserver.TeiserverTestLib

  alias Teiserver.{Account, CacheUser, Client}

  @moduletag :load_test
  @moduletag timeout: 120_000

  describe "concurrent user creation" do
    @tag :load_test
    test "creates multiple users concurrently" do
      user_count = 10

      start_time = System.monotonic_time(:millisecond)

      tasks =
        1..user_count
        |> Enum.map(fn i ->
          Task.async(fn ->
            name = "load_test_user_#{i}_#{:rand.uniform(999_999)}"

            result =
              CacheUser.user_register_params_with_md5(
                name,
                "#{name}@email.com",
                Account.spring_md5_password("password"),
                %{}
              )
              |> Account.create_user()

            case result do
              {:ok, user} -> {:ok, user.id}
              error -> error
            end
          end)
        end)

      results = Task.await_many(tasks, 60_000)
      end_time = System.monotonic_time(:millisecond)

      successful = Enum.count(results, fn r -> match?({:ok, _}, r) end)
      elapsed_ms = end_time - start_time

      IO.puts("\n=== Concurrent User Creation Results ===")
      IO.puts("Total users attempted: #{user_count}")
      IO.puts("Successful creations: #{successful}")
      IO.puts("Failed creations: #{user_count - successful}")
      IO.puts("Total time: #{elapsed_ms}ms")
      IO.puts("Average time per user: #{Float.round(elapsed_ms / user_count, 2)}ms")
      IO.puts("Users per second: #{Float.round(successful / (elapsed_ms / 1000), 2)}")

      assert successful >= user_count * 0.95,
             "Expected at least 95% success rate, got #{successful}/#{user_count}"
    end
  end

  describe "concurrent client logins" do
    @tag :load_test
    test "handles multiple simultaneous login attempts" do
      user_count = 30

      # First, create users
      users =
        1..user_count
        |> Enum.map(fn _ -> new_user() end)

      start_time = System.monotonic_time(:millisecond)

      tasks =
        users
        |> Enum.map(fn user ->
          Task.async(fn ->
            token = CacheUser.create_token(user)

            result = CacheUser.try_login(token, "127.0.0.1", "LoadTest", "token1 token2")

            case result do
              {:ok, _user} ->
                Client.login(user, :test, "127.0.0.1")
                {:ok, user.id}

              error ->
                error
            end
          end)
        end)

      results = Task.await_many(tasks, 60_000)
      end_time = System.monotonic_time(:millisecond)

      successful = Enum.count(results, fn r -> match?({:ok, _}, r) end)
      elapsed_ms = end_time - start_time

      IO.puts("\n=== Concurrent Client Login Results ===")
      IO.puts("Total logins attempted: #{user_count}")
      IO.puts("Successful logins: #{successful}")
      IO.puts("Failed logins: #{user_count - successful}")
      IO.puts("Total time: #{elapsed_ms}ms")
      IO.puts("Average time per login: #{Float.round(elapsed_ms / user_count, 2)}ms")
      IO.puts("Logins per second: #{Float.round(successful / (elapsed_ms / 1000), 2)}")

      # Cleanup
      Enum.each(users, fn user ->
        Client.disconnect(user.id)
      end)

      assert successful >= user_count * 0.90,
             "Expected at least 90% success rate, got #{successful}/#{user_count}"
    end
  end

  describe "concurrent cache operations" do
    @tag :load_test
    test "handles rapid user cache lookups" do
      # Create test users first
      users = Enum.map(1..20, fn _ -> new_user() end)

      lookup_count = 500

      start_time = System.monotonic_time(:millisecond)

      tasks =
        1..lookup_count
        |> Enum.map(fn _ ->
          Task.async(fn ->
            user = Enum.random(users)
            result = CacheUser.get_user_by_id(user.id)
            if result, do: :ok, else: :error
          end)
        end)

      results = Task.await_many(tasks, 30_000)
      end_time = System.monotonic_time(:millisecond)

      successful = Enum.count(results, &(&1 == :ok))
      elapsed_ms = end_time - start_time

      IO.puts("\n=== Concurrent Cache Lookup Results ===")
      IO.puts("Total lookups: #{lookup_count}")
      IO.puts("Successful lookups: #{successful}")
      IO.puts("Total time: #{elapsed_ms}ms")
      IO.puts("Lookups per second: #{Float.round(lookup_count / (elapsed_ms / 1000), 2)}")

      assert successful == lookup_count, "All cache lookups should succeed"
    end
  end

  describe "database stress test" do
    @tag :load_test
    test "handles concurrent database writes" do
      user = new_user()
      write_count = 100

      start_time = System.monotonic_time(:millisecond)

      tasks =
        1..write_count
        |> Enum.map(fn i ->
          Task.async(fn ->
            result =
              Account.update_user_stat(user.id, %{
                "load_test_key_#{i}" => "value_#{i}",
                "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601()
              })

            case result do
              {:ok, _} -> :ok
              _ -> :error
            end
          end)
        end)

      results = Task.await_many(tasks, 60_000)
      end_time = System.monotonic_time(:millisecond)

      successful = Enum.count(results, &(&1 == :ok))
      elapsed_ms = end_time - start_time

      IO.puts("\n=== Database Write Stress Results ===")
      IO.puts("Total writes: #{write_count}")
      IO.puts("Successful writes: #{successful}")
      IO.puts("Total time: #{elapsed_ms}ms")
      IO.puts("Writes per second: #{Float.round(write_count / (elapsed_ms / 1000), 2)}")

      assert successful >= write_count * 0.95,
             "Expected at least 95% success rate for DB writes"
    end
  end
end
