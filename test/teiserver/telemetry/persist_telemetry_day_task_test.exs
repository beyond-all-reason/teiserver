defmodule Teiserver.Tasks.PersistTelemetryDayTaskTest do
  use Central.DataCase
  alias Teiserver.Telemetry
  alias Teiserver.Tasks.PersistTelemetryDayTask

  test "perform task" do
    # Make some data
    create_minute_data()

    # Run the task
    assert :ok == PersistTelemetryDayTask.perform(%{})

    # Now ensure it ran
    log = Telemetry.get_telemetry_day_log(Timex.to_date({2021, 1, 1}))

    assert log.date == Timex.to_date({2021, 1, 1})
    assert is_integer(log.data["aggregates"]["minutes"]["lobby"])
  end

  defp create_minute_data() do
    user_ids = Teiserver.User.list_users()
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
      Telemetry.create_telemetry_minute_log(params)
    end)
  end
end
