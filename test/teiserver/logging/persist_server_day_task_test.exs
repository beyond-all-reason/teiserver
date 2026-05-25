defmodule Teiserver.Logging.Tasks.PersistServerDayTaskTest do
  @moduledoc false

  alias Teiserver.Account
  alias Teiserver.AccountFixtures
  alias Teiserver.CacheUser
  alias Teiserver.Logging
  alias Teiserver.Logging.Tasks.PersistServerDayTask
  use Teiserver.DataCase

  test "perform task" do
    # Make some data
    create_minute_data()

    # Run the task
    assert :ok == PersistServerDayTask.perform(%{})

    # Now ensure it ran
    log = Date.new!(2021, 1, 1) |> Logging.get_server_day_log()

    assert log.date == Date.new!(2021, 1, 1)
    assert is_integer(log.data["aggregates"]["minutes"]["lobby"])
  end

  defp create_minute_data do
    AccountFixtures.user_fixture()
    AccountFixtures.user_fixture()

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
        "timestamp" => DateTime.new!(~D[2021-01-01], ~T[01:01:00], "Etc/UTC"),
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
        "timestamp" => DateTime.new!(~D[2021-01-01], ~T[01:02:00], "Etc/UTC"),
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
        "timestamp" => DateTime.new!(~D[2021-01-01], ~T[01:03:00], "Etc/UTC"),
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
        "timestamp" => DateTime.new!(~D[2021-01-01], ~T[10:23:00], "Etc/UTC"),
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
    |> Enum.map(fn params ->
      Logging.create_server_minute_log(params)
    end)
  end
end
