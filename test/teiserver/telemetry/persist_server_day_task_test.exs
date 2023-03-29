defmodule Teiserver.Telemetry.Tasks.PersistServerDayTaskTest do
  use Central.DataCase
  alias Teiserver.{Telemetry, Account, User}
  alias Teiserver.Telemetry.Tasks.PersistServerDayTask

  test "perform task" do
    # Make some data
    create_minute_data()

    # Run the task
    assert :ok == PersistServerDayTask.perform(%{})

    # Now ensure it ran
    log = Telemetry.get_server_day_log(Timex.to_date({2021, 1, 1}))

    assert log.date == Timex.to_date({2021, 1, 1})
    assert is_integer(log.data["aggregates"]["minutes"]["lobby"])
  end

  defp create_minute_data() do
    all_ids =
      Account.list_users()
      |> Enum.map(fn u -> u.id end)

    user_ids =
      all_ids
      |> User.list_users()
      |> Enum.filter(fn u -> u.bot == false end)
      |> Enum.map(fn u -> u.id end)

    [u1, u2 | remaining] = user_ids

    [
      %{
        "timestamp" => Timex.to_datetime({{2021, 1, 1}, {1, 1, 0}}, :local),
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
        "timestamp" => Timex.to_datetime({{2021, 1, 1}, {1, 2, 0}}, :local),
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
        "timestamp" => Timex.to_datetime({{2021, 1, 1}, {1, 3, 0}}, :local),
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
        "timestamp" => Timex.to_datetime({{2021, 1, 1}, {10, 23, 0}}, :local),
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
      Telemetry.create_server_minute_log(params)
    end)
  end
end
