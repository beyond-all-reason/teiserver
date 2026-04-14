defmodule Teiserver.Logging.Tasks.PersistServerMonthTaskTest do
  @moduledoc false

  alias Teiserver.Account
  alias Teiserver.AccountFixtures
  alias Teiserver.CacheUser
  alias Teiserver.Logging
  alias Teiserver.Logging.Tasks.PersistServerDayTask
  alias Teiserver.Logging.Tasks.PersistServerMonthTask

  use Teiserver.DataCase

  test "perform task" do
    AccountFixtures.user_fixture()
    AccountFixtures.user_fixture()
    AccountFixtures.user_fixture()

    # Make some data
    create_day_data(1)
    create_day_data(2)
    create_day_data(3)

    # Run the task
    assert :ok == PersistServerMonthTask.perform(%{})

    # Now ensure it ran
    log = Logging.get_server_month_log({2021, 1})

    assert log.year == 2021
    assert log.month == 1
    assert Map.keys(log.data) == ["aggregates", "events"]
    assert Map.keys(log.data["aggregates"]) == ["minutes", "stats"]
  end

  defp create_day_data(day) do
    all_ids =
      Account.list_users()
      |> Enum.map(fn u -> u.id end)

    user_ids =
      all_ids
      |> CacheUser.list_users()
      |> Enum.filter(fn u -> u.bot == false end)
      |> Enum.map(fn u -> u.id end)

    [u1, u2 | remaining] = user_ids

    [
      %{
        "timestamp" => Timex.to_datetime({{2021, 1, day}, {1, 1, 0}}, :local),
        "data" => %{
          "battle" => %{"in_progress" => 1, "lobby" => 2, "total" => 3},
          "client" => %{
            "lobby" => user_ids,
            "menu" => [],
            "player" => [],
            "spectator" => [],
            "total" => user_ids
          }
        }
      },
      %{
        "timestamp" => Timex.to_datetime({{2021, 1, day}, {1, 2, 0}}, :local),
        "data" => %{
          "battle" => %{"in_progress" => 1, "lobby" => 2, "total" => 3},
          "client" => %{
            "lobby" => remaining,
            "menu" => [],
            "player" => [u1],
            "spectator" => [u2],
            "total" => user_ids
          }
        }
      },
      %{
        "timestamp" => Timex.to_datetime({{2021, 1, day}, {1, 3, 0}}, :local),
        "data" => %{
          "battle" => %{"in_progress" => 4, "lobby" => 4, "total" => 8},
          "client" => %{
            "lobby" => remaining,
            "menu" => [],
            "player" => [u1],
            "spectator" => [u2],
            "total" => user_ids
          }
        }
      },
      # Another segment
      %{
        "timestamp" => Timex.to_datetime({{2021, 1, day}, {10, 23, 0}}, :local),
        "data" => %{
          "battle" => %{"in_progress" => 4, "lobby" => 4, "total" => 8},
          "client" => %{
            "lobby" => remaining,
            "menu" => [],
            "player" => [u1],
            "spectator" => [u2],
            "total" => user_ids
          }
        }
      }
    ]
    |> Enum.each(fn params ->
      Logging.create_server_minute_log(params)
    end)

    create_activity_data(day)

    # Now create the day data
    assert :ok == PersistServerDayTask.perform(%{})
  end

  defp create_activity_data(day) do
    user_ids =
      Account.list_users()
      |> Enum.map(fn u -> u.id end)
      |> CacheUser.list_users()
      |> Enum.filter(fn u -> u.bot == false end)
      |> Enum.map(fn u -> u.id end)

    activity_data = %{
      total: Map.new(user_ids, fn id -> {id, :rand.uniform(100)} end),
      player: Map.new(user_ids, fn id -> {id, :rand.uniform(100)} end),
      spectator: Map.new(user_ids, fn id -> {id, :rand.uniform(100)} end),
      lobby: Map.new(user_ids, fn id -> {id, :rand.uniform(100)} end),
      menu: Map.new(user_ids, fn id -> {id, :rand.uniform(100)} end)
    }

    # Next, user activity data
    Logging.create_user_activity_day_log(%{
      "date" => Date.new(2021, 1, day),
      "data" => activity_data
    })
  end
end
