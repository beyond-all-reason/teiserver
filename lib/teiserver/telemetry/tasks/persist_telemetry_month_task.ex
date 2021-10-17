defmodule Teiserver.Telemetry.Tasks.PersistTelemetryMonthTask do
  use Oban.Worker, queue: :teiserver
  alias Teiserver.Telemetry
  alias Central.NestedMaps
  import Ecto.Query, warn: false

  # [] List means 1 day segments
  # %{} Dict means total for the month of that key
  # 0 Integer means sum or average
  @empty_log %{
    # Average battle counts per segment
    battles: %{
      total: [],
    },

    # Used to make calculating the end of month stats easier, this will not appear in the final result
    tmp_reduction: %{
      unique_users: [],
      unique_players: [],
      accounts_created: 0,
      peak_users: 0,
      peak_players: 0,
    },

    # Monthly totals
    aggregates: %{
      stats: %{
        accounts_created: 0,
        unique_users: 0,
        unique_players: 0,
        battles: 0
      },

      # Total number of minutes spent doing that across all players that month
      minutes: %{
        player: 0,
        spectator: 0,
        lobby: 0,
        menu: 0,
        total: 0
      }
    }
  }

  @impl Oban.Worker
  @spec perform(any) :: :ok
  def perform(_) do
    log = case Telemetry.get_last_telemetry_month_log() do
      nil ->
        perform_first_time()

      {year, month} ->
        {y, m} = next_month({year, month})
        perform_standard(y, m)
    end

    if log != nil do
      %{}
      |> Teiserver.Telemetry.Tasks.PersistTelemetryMonthTask.new()
      |> Oban.insert()
    end

    :ok
  end

  # For when there are no existing logs
  # we need to ensure the earliest log is from last month, not this month
  defp perform_first_time() do
    first_logs = Telemetry.list_telemetry_day_logs(
      order: "Oldest first",
      limit: 1
    )

    case first_logs do
      [log] ->
        today = Timex.today()

        if log.date.year < today.year or log.date.month < today.month do
          run(log.date.year, log.date.month)
        end
      _ ->
        nil
    end
  end

  # For when we have an existing log
  defp perform_standard(year, month) do
    today = Timex.today()
    if year < today.year or month < today.month do
      run(year, month)
    else
      nil
    end
  end

  @spec run(integer(), integer()) :: :ok
  def run(year, month) do
    now = Timex.Date.new!(year, month, 1)

    Telemetry.list_telemetry_day_logs(search: [
      start_date: Timex.beginning_of_month(now),
      end_date: Timex.end_of_month(now)
    ])

    data = Telemetry.list_telemetry_day_logs(search: [
      start_date: Timex.beginning_of_month(now),
      end_date: Timex.end_of_month(now)
    ])
    |> Enum.reduce(@empty_log, fn (log, acc) ->
      extend_segment(acc, log)
    end)
    |> calculate_month_statistics()

    Telemetry.create_telemetry_month_log(%{
      year: year,
      month: month,
      data: data
    })

    :ok
  end

  def month_so_far() do
    now = Timex.now()

    Telemetry.list_telemetry_day_logs(search: [
      start_date: Timex.beginning_of_month(now)
    ])
    |> Enum.reduce(@empty_log, fn (log, acc) ->
      extend_segment(acc, log)
    end)
    |> calculate_month_statistics()
    |> Jason.encode!
    |> Jason.decode!
    # We encode and decode so it's the same format as in the database
  end

  # Given an existing segment and a batch of logs, calculate the segment and add them together
  defp extend_segment(existing, %{data: data} = _log) do
    %{
      # Average battle counts per segment
      battles: %{
        total: existing.battles.total ++ [data["aggregates"]["stats"]["battles"]],
      },

      # Used to make calculating the end of day stats easier, this will not appear in the final result
      tmp_reduction: %{
        unique_users: existing.tmp_reduction.unique_users ++ Map.keys(data["minutes_per_user"]["total"]),
        unique_players: existing.tmp_reduction.unique_players ++ Map.keys(data["minutes_per_user"]["player"]),
        accounts_created: existing.tmp_reduction.accounts_created + data["aggregates"]["stats"]["accounts_created"],
        peak_users: max(existing.tmp_reduction.peak_players, data["aggregates"]["stats"]["unique_users"]),
        peak_players: max(existing.tmp_reduction.peak_players, data["aggregates"]["stats"]["unique_players"]),
      },

      # Monthly totals
      aggregates: %{
        stats: %{
          accounts_created: 0,
          unique_users: 0,
          unique_players: 0,
          battles: 0
        },

        # Total number of minutes spent doing that across all players that month
        minutes: %{
          player: existing.aggregates.minutes.player + data["aggregates"]["minutes"]["player"],
          spectator: existing.aggregates.minutes.spectator + data["aggregates"]["minutes"]["spectator"],
          lobby: existing.aggregates.minutes.lobby + data["aggregates"]["minutes"]["lobby"],
          menu: existing.aggregates.minutes.menu + data["aggregates"]["minutes"]["menu"],
          total: existing.aggregates.minutes.total + data["aggregates"]["minutes"]["total"]
        },
      }
    }
  end

  # Given a day log, calculate the end of day stats
  defp calculate_month_statistics(data) do
    # TODO: Calculate number of battles that took place
    battles = 0

    aggregate_stats = %{
      accounts_created: data.tmp_reduction.accounts_created,
      unique_users: data.tmp_reduction.unique_users |> Enum.uniq |> Enum.count,
      unique_players: data.tmp_reduction.unique_players |> Enum.uniq |> Enum.count,
      peak_users: data.tmp_reduction.peak_users,
      peak_players: data.tmp_reduction.peak_players,
      battles: battles
    }

    NestedMaps.put(data, ~w(aggregates stats)a, aggregate_stats)
    |> Map.delete(:tmp_reduction)
  end

  defp next_month({year, 12}), do: {year+1, 1}
  defp next_month({year, month}), do: {year, month+1}
end
