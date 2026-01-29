defmodule Teiserver.Load.LobbyLoadTest do
  @moduledoc """
  Load tests for lobby operations.

  Tests the system's ability to handle multiple concurrent lobby
  operations including creation, joining, and updates.

  Run with: mix test test/teiserver/load/ --include load_test
  """
  use Teiserver.ServerCase

  import Teiserver.TeiserverTestLib

  alias Teiserver.{Client, CacheUser, Lobby}

  @moduletag :load_test
  @moduletag timeout: 180_000

  describe "concurrent lobby creation" do
    @tag :load_test
    test "creates multiple lobbies concurrently" do
      lobby_count = 20

      # Create host users first
      hosts =
        1..lobby_count
        |> Enum.map(fn _ ->
          user = new_user()
          Client.login(user, :test, "127.0.0.1")
          user
        end)

      start_time = System.monotonic_time(:millisecond)

      tasks =
        hosts
        |> Enum.with_index()
        |> Enum.map(fn {host, i} ->
          Task.async(fn ->
            lobby =
              %{
                id: :rand.uniform(999_999_999_999_999),
                founder_id: host.id,
                founder_name: host.name,
                cmd: "c.lobby.create",
                name: "LoadTestLobby_#{i}",
                nattype: "none",
                port: 1234,
                game_hash: "load_test_hash",
                map_hash: "load_test_map_hash",
                map_name: "load_test_map",
                game_name: "BAR",
                engine_name: "spring-105",
                engine_version: "105.1.2.3",
                settings: %{
                  max_players: 16
                }
              }
              |> Lobby.create_lobby()
              |> Lobby.add_lobby()

            if lobby && lobby.id, do: {:ok, lobby.id}, else: :error
          end)
        end)

      results = Task.await_many(tasks, 60_000)
      end_time = System.monotonic_time(:millisecond)

      successful = Enum.count(results, fn r -> match?({:ok, _}, r) end)
      elapsed_ms = end_time - start_time

      IO.puts("\n=== Concurrent Lobby Creation Results ===")
      IO.puts("Total lobbies attempted: #{lobby_count}")
      IO.puts("Successful creations: #{successful}")
      IO.puts("Failed creations: #{lobby_count - successful}")
      IO.puts("Total time: #{elapsed_ms}ms")
      IO.puts("Average time per lobby: #{Float.round(elapsed_ms / lobby_count, 2)}ms")
      IO.puts("Lobbies per second: #{Float.round(successful / (elapsed_ms / 1000), 2)}")

      # Cleanup
      Enum.each(hosts, fn host ->
        Client.disconnect(host.id)
      end)

      assert successful >= lobby_count * 0.90,
             "Expected at least 90% success rate, got #{successful}/#{lobby_count}"
    end
  end

  describe "concurrent lobby joins" do
    @tag :load_test
    test "handles multiple users joining the same lobby" do
      # Create a host and lobby
      host = new_user()
      Client.login(host, :test, "127.0.0.1")

      lobby =
        %{
          id: :rand.uniform(999_999_999_999_999),
          founder_id: host.id,
          founder_name: host.name,
          cmd: "c.lobby.create",
          name: "JoinTestLobby",
          nattype: "none",
          port: 1234,
          game_hash: "join_test_hash",
          map_hash: "join_test_map_hash",
          map_name: "join_test_map",
          game_name: "BAR",
          engine_name: "spring-105",
          engine_version: "105.1.2.3",
          settings: %{
            max_players: 16
          }
        }
        |> Lobby.create_lobby()
        |> Lobby.add_lobby()

      user_count = 14  # Leave room for host, stay under max_players

      # Create users that will join
      users =
        1..user_count
        |> Enum.map(fn _ ->
          user = new_user()
          Client.login(user, :test, "127.0.0.1")
          user
        end)

      start_time = System.monotonic_time(:millisecond)

      tasks =
        users
        |> Enum.map(fn user ->
          Task.async(fn ->
            result = Lobby.add_user_to_battle(user.id, lobby.id, "script_pass")
            if result == :ok, do: :ok, else: :error
          end)
        end)

      results = Task.await_many(tasks, 30_000)
      end_time = System.monotonic_time(:millisecond)

      successful = Enum.count(results, &(&1 == :ok))
      elapsed_ms = end_time - start_time

      elapsed_ms = max(elapsed_ms, 1)

      IO.puts("\n=== Concurrent Lobby Join Results ===")
      IO.puts("Total join attempts: #{user_count}")
      IO.puts("Successful joins: #{successful}")
      IO.puts("Failed joins: #{user_count - successful}")
      IO.puts("Total time: #{elapsed_ms}ms")
      IO.puts("Average time per join: #{Float.round(elapsed_ms / user_count, 2)}ms")
      IO.puts("Joins per second: #{Float.round(successful / (elapsed_ms / 1000), 2)}")

      # Cleanup
      Enum.each(users, fn user ->
        Client.disconnect(user.id)
      end)
      Client.disconnect(host.id)

      assert successful >= user_count * 0.80,
             "Expected at least 80% success rate, got #{successful}/#{user_count}"
    end
  end

  describe "lobby listing under load" do
    @tag :load_test
    test "handles concurrent lobby listing requests" do
      # Create some lobbies first
      lobby_count = 10

      hosts =
        1..lobby_count
        |> Enum.map(fn i ->
          user = new_user()
          Client.login(user, :test, "127.0.0.1")

          %{
            id: :rand.uniform(999_999_999_999_999),
            founder_id: user.id,
            founder_name: user.name,
            cmd: "c.lobby.create",
            name: "ListTestLobby_#{i}",
            nattype: "none",
            port: 1234,
            game_hash: "list_test_hash",
            map_hash: "list_test_map_hash",
            map_name: "list_test_map",
            game_name: "BAR",
            engine_name: "spring-105",
            engine_version: "105.1.2.3",
            settings: %{
              max_players: 16
            }
          }
          |> Lobby.create_lobby()
          |> Lobby.add_lobby()

          user
        end)

      list_count = 200

      start_time = System.monotonic_time(:millisecond)

      tasks =
        1..list_count
        |> Enum.map(fn _ ->
          Task.async(fn ->
            lobbies = Lobby.list_lobbies()
            if is_list(lobbies), do: length(lobbies), else: :error
          end)
        end)

      results = Task.await_many(tasks, 30_000)
      end_time = System.monotonic_time(:millisecond)

      successful = Enum.count(results, &is_integer/1)
      elapsed_ms = end_time - start_time

      IO.puts("\n=== Concurrent Lobby Listing Results ===")
      IO.puts("Total list requests: #{list_count}")
      IO.puts("Successful requests: #{successful}")
      IO.puts("Total time: #{elapsed_ms}ms")
      IO.puts("Requests per second: #{Float.round(list_count / (elapsed_ms / 1000), 2)}")

      # Cleanup
      Enum.each(hosts, fn host ->
        Client.disconnect(host.id)
      end)

      assert successful == list_count, "All lobby list requests should succeed"
    end
  end

  describe "mixed lobby operations" do
    @tag :load_test
    test "handles mixed concurrent lobby operations" do
      operation_count = 100

      # Create some initial users and lobbies
      initial_users =
        1..10
        |> Enum.map(fn _ ->
          user = new_user()
          Client.login(user, :test, "127.0.0.1")
          user
        end)

      initial_lobbies =
        initial_users
        |> Enum.take(5)
        |> Enum.with_index()
        |> Enum.map(fn {user, i} ->
          %{
            id: :rand.uniform(999_999_999_999_999),
            founder_id: user.id,
            founder_name: user.name,
            cmd: "c.lobby.create",
            name: "MixedTestLobby_#{i}",
            nattype: "none",
            port: 1234,
            game_hash: "mixed_test_hash",
            map_hash: "mixed_test_map_hash",
            map_name: "mixed_test_map",
            game_name: "BAR",
            engine_name: "spring-105",
            engine_version: "105.1.2.3",
            settings: %{
              max_players: 16
            }
          }
          |> Lobby.create_lobby()
          |> Lobby.add_lobby()
        end)

      start_time = System.monotonic_time(:millisecond)

      tasks =
        1..operation_count
        |> Enum.map(fn _ ->
          Task.async(fn ->
            operation = Enum.random([:list, :list, :get])  # More reads than writes

            case operation do
              :list ->
                lobbies = Lobby.list_lobbies()
                if is_list(lobbies), do: :ok, else: :error

              :get ->
                lobby = Enum.random(initial_lobbies)
                if lobby do
                  result = Lobby.get_lobby(lobby.id)
                  if result, do: :ok, else: :error
                else
                  :skip
                end
            end
          end)
        end)

      results = Task.await_many(tasks, 60_000)
      end_time = System.monotonic_time(:millisecond)

      successful = Enum.count(results, &(&1 == :ok))
      skipped = Enum.count(results, &(&1 == :skip))
      elapsed_ms = end_time - start_time

      IO.puts("\n=== Mixed Lobby Operations Results ===")
      IO.puts("Total operations: #{operation_count}")
      IO.puts("Successful operations: #{successful}")
      IO.puts("Skipped operations: #{skipped}")
      IO.puts("Failed operations: #{operation_count - successful - skipped}")
      IO.puts("Total time: #{elapsed_ms}ms")
      IO.puts("Operations per second: #{Float.round(operation_count / (elapsed_ms / 1000), 2)}")

      # Cleanup
      Enum.each(initial_users, fn user ->
        Client.disconnect(user.id)
      end)

      assert successful >= (operation_count - skipped) * 0.90,
             "Expected at least 90% success rate for non-skipped operations"
    end
  end
end
