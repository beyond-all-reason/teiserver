defmodule Teiserver.Load.RatingMatchmakingLoadTest do
  @moduledoc """
  Load tests for rating and matchmaking systems.

  Tests the system's ability to handle rating calculations and
  matchmaking operations under load.

  Run with: mix test test/teiserver/load/ --include load_test
  """
  use Teiserver.ServerCase

  import Teiserver.TeiserverTestLib

  alias Teiserver.{Account, Client, CacheUser, Game}
  alias Teiserver.Battle.BalanceLib

  @moduletag :load_test
  @moduletag timeout: 180_000

  describe "rating calculations" do
    @tag :load_test
    test "handles concurrent rating lookups" do
      # Create users (ratings will be created on-demand with defaults)
      user_count = 30
      rating_type_id = Game.get_or_add_rating_type("Team")

      users =
        1..user_count
        |> Enum.map(fn _ -> new_user() end)

      lookup_count = 200

      start_time = System.monotonic_time(:millisecond)

      tasks =
        1..lookup_count
        |> Enum.map(fn _ ->
          Task.async(fn ->
            user = Enum.random(users)
            # get_rating returns nil if not found, which is expected for new users
            # The system uses default ratings when none exist
            _rating = Account.get_rating(user.id, rating_type_id)
            :ok
          end)
        end)

      results = Task.await_many(tasks, 60_000)
      end_time = System.monotonic_time(:millisecond)

      successful = Enum.count(results, &(&1 == :ok))
      elapsed_ms = max(end_time - start_time, 1)

      IO.puts("\n=== Rating Lookup Results ===")
      IO.puts("Total lookups: #{lookup_count}")
      IO.puts("Successful lookups: #{successful}")
      IO.puts("Total time: #{elapsed_ms}ms")
      IO.puts("Lookups per second: #{Float.round(lookup_count / (elapsed_ms / 1000), 2)}")

      assert successful == lookup_count, "All rating lookups should complete"
    end
  end

  describe "balance calculations" do
    @tag :load_test
    test "handles concurrent team balance calculations" do
      # Create players with different skill levels
      players_per_team = 4
      team_count = 2
      total_players = players_per_team * team_count

      # Create player groups - each group is a map of userid => player_data
      # For balancing, we pass a list of these groups
      player_pool =
        1..20
        |> Enum.map(fn i ->
          {i, %{
            rating: 20.0 + :rand.uniform() * 15,
            uncertainty: 2.0 + :rand.uniform() * 3,
            rank: :rand.uniform(10),
            name: "Player_#{i}"
          }}
        end)
        |> Map.new()

      balance_count = 50

      start_time = System.monotonic_time(:millisecond)

      tasks =
        1..balance_count
        |> Enum.map(fn _ ->
          Task.async(fn ->
            # Select random players for this balance calculation
            selected_ids = Enum.take_random(Map.keys(player_pool), total_players)

            # Create groups - each player is their own group (solo queue style)
            groups =
              selected_ids
              |> Enum.map(fn id ->
                %{id => Map.get(player_pool, id)}
              end)

            result =
              BalanceLib.create_balance(
                groups,
                team_count,
                mode: :loser_picks
              )

            if result && Map.has_key?(result, :team_players), do: :ok, else: :error
          end)
        end)

      results = Task.await_many(tasks, 60_000)
      end_time = System.monotonic_time(:millisecond)

      successful = Enum.count(results, &(&1 == :ok))
      elapsed_ms = end_time - start_time

      IO.puts("\n=== Balance Calculation Results ===")
      IO.puts("Total calculations: #{balance_count}")
      IO.puts("Successful balances: #{successful}")
      IO.puts("Failed balances: #{balance_count - successful}")
      IO.puts("Total time: #{elapsed_ms}ms")
      IO.puts("Balances per second: #{Float.round(balance_count / (elapsed_ms / 1000), 2)}")
      IO.puts("Average time per balance: #{Float.round(elapsed_ms / balance_count, 2)}ms")

      assert successful >= balance_count * 0.95,
             "Expected at least 95% success rate for balance calculations"
    end

    @tag :load_test
    test "handles large team balance calculations" do
      # Test with larger teams (8v8)
      players_per_team = 8
      team_count = 2
      total_players = players_per_team * team_count

      player_pool =
        1..50
        |> Enum.map(fn i ->
          {i, %{
            rating: 15.0 + :rand.uniform() * 20,
            uncertainty: 2.0 + :rand.uniform() * 4,
            rank: :rand.uniform(15),
            name: "LargePlayer_#{i}"
          }}
        end)
        |> Map.new()

      balance_count = 20

      start_time = System.monotonic_time(:millisecond)

      tasks =
        1..balance_count
        |> Enum.map(fn _ ->
          Task.async(fn ->
            selected_ids = Enum.take_random(Map.keys(player_pool), total_players)

            groups =
              selected_ids
              |> Enum.map(fn id ->
                %{id => Map.get(player_pool, id)}
              end)

            result =
              BalanceLib.create_balance(
                groups,
                team_count,
                mode: :loser_picks
              )

            if result && Map.has_key?(result, :team_players), do: :ok, else: :error
          end)
        end)

      results = Task.await_many(tasks, 120_000)
      end_time = System.monotonic_time(:millisecond)

      successful = Enum.count(results, &(&1 == :ok))
      elapsed_ms = end_time - start_time

      IO.puts("\n=== Large Team Balance Results (#{total_players} players) ===")
      IO.puts("Total calculations: #{balance_count}")
      IO.puts("Successful balances: #{successful}")
      IO.puts("Total time: #{elapsed_ms}ms")
      IO.puts("Average time per balance: #{Float.round(elapsed_ms / balance_count, 2)}ms")

      assert successful >= balance_count * 0.90,
             "Expected at least 90% success rate for large team balances"
    end
  end

  describe "concurrent user stats updates" do
    @tag :load_test
    test "handles concurrent stat updates" do
      user_count = 20
      updates_per_user = 10

      users = Enum.map(1..user_count, fn _ -> new_user() end)

      start_time = System.monotonic_time(:millisecond)

      tasks =
        users
        |> Enum.flat_map(fn user ->
          1..updates_per_user
          |> Enum.map(fn i ->
            Task.async(fn ->
              result =
                Account.update_user_stat(user.id, %{
                  "games_played" => i,
                  "last_game_time" => DateTime.utc_now() |> DateTime.to_iso8601(),
                  "win_count" => :rand.uniform(i),
                  "total_playtime_minutes" => :rand.uniform(1000)
                })

              case result do
                {:ok, _} -> :ok
                _ -> :error
              end
            end)
          end)
        end)

      results = Task.await_many(tasks, 120_000)
      end_time = System.monotonic_time(:millisecond)

      total_updates = user_count * updates_per_user
      successful = Enum.count(results, &(&1 == :ok))
      elapsed_ms = end_time - start_time

      IO.puts("\n=== Concurrent Stat Update Results ===")
      IO.puts("Total updates: #{total_updates}")
      IO.puts("Successful updates: #{successful}")
      IO.puts("Failed updates: #{total_updates - successful}")
      IO.puts("Total time: #{elapsed_ms}ms")
      IO.puts("Updates per second: #{Float.round(total_updates / (elapsed_ms / 1000), 2)}")

      assert successful >= total_updates * 0.90,
             "Expected at least 90% success rate for stat updates"
    end
  end
end
