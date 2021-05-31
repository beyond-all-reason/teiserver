defmodule Teiserver.Tasks.PersistTelemetryDayTask do
  use Oban.Worker, queue: :teiserver
  alias Teiserver.Telemetry
  alias Central.NestedMaps
  alias Central.Account

  alias Central.Repo
  import Ecto.Query, warn: false

  @log_keep_days 35
  @segment_length 60# Minutes
  @segment_count div(1440, @segment_length)-1

  # [] List means 15 minute segments
  # %{} Dict means total for the day for that key
  # 0 Integer means sum or average
  @empty_log %{
    # Average battle counts per segment
    battles: %{
      in_progress: [],
      lobby: [],
      total: [],
    },

    # Used to make calculating the end of day stats easier, this will not appear in the final result
    tmp_reduction: %{
      unique_users: [],
      unique_players: []
    },

    # Daily totals
    aggregates: %{
      stats: %{
        accounts_created: 0,
        unique_users: 0,
        unique_players: 0,
        battles: 0# Currently we can't track when a battle starts and ends correctly
      },

      # Total number of minutes spent doing that across all players that day
      minutes: %{
        player: 0,
        spectator: 0,
        lobby: 0,
        menu: 0,
        total: 0
      }
    },

    # The number of minutes users (combined) spent in that state during the segment
    user_counts: %{
      player: [],
      spectator: [],
      lobby: [],
      menu: [],
      total: []
    },

    # Per user minute counts for the day as a whole
    minutes_per_user: %{
      total: %{},
      player: %{},
      spectator: %{},
      lobby: %{},
      menu: %{}
    }
  }

  # Average battle counts per segment
  @empty_segment %{
    battles: %{
      in_progress: 0,
      lobby: 0,
      total: 0,
    },

    # Used to make calculating the end of day stats easier, this will not appear in the final result
    tmp_reduction: %{
      unique_users: [],
      unique_players: []
    },

    # Daily totals
    aggregates: %{
      stats: %{
        accounts_created: 0,
        unique_users: 0,
        unique_players: 0,
        battles: 0# Currently we can't track when a battle starts and ends correctly
      },

      # Total number of minutes spent doing that across all players that day
      minutes: %{
        player: 0,
        spectator: 0,
        lobby: 0,
        menu: 0,
        total: 0
      },
    },

    # The number of minutes users (combined) spent in that state during the segment
    user_counts: %{
      player: 0,
      spectator: 0,
      lobby: 0,
      menu: 0,
      total: 0
    },

    # Per user minute counts for the day as a whole
    minutes_per_user: %{
      total: %{},
      player: %{},
      spectator: %{},
      lobby: %{},
      menu: %{}
    }
  }

  @impl Oban.Worker
  @spec perform(any) :: :ok
  def perform(_) do
    last_date = Telemetry.get_last_telemtry_day_log()

    date =
      if last_date == nil do
        Telemetry.get_first_telemetry_minute_datetime()
        |> Timex.to_date()
      else
        last_date
        |> Timex.shift(days: 1)
      end

    if Timex.compare(date, Timex.today()) == -1 do
      run(date, cleanup: true)

      new_date = Timex.shift(date, days: 1)

      if Timex.compare(new_date, Timex.today()) == -1 do
        %{}
        |> Central.Logging.AggregateViewLogsTask.new()
        |> Oban.insert()
      end
    end

    :ok
  end

  @spec run(%Date{}, boolean()) :: :ok
  defp run(date, cleanup) do
    data = 0..@segment_count
    |> Enum.reduce(@empty_log, fn (segment_number, segment) ->
      logs = get_logs(date, segment_number)
      extend_segment(segment, logs)
    end)
    |> calculate_day_statistics(date)

    if cleanup do
      clean_up_logs(date)
    end

    # Delete old log if it exists
    delete_query =
      from logs in Teiserver.Telemetry.TelemetryDayLog,
        where: logs.date == ^(date |> Timex.to_date())

    Repo.delete_all(delete_query)

    Telemetry.create_telemetry_day_log(%{
      date: date,
      data: data
    })

    :ok
  end

  # Given an existing segment and a batch of logs, calculate the segment and add them together
  defp extend_segment(segment, logs) do
    extend = calculate_segment_parts(logs)

    %{
      # Average battle counts per segment
      battles: %{
        in_progress: segment.battles.in_progress ++ [extend.battles.in_progress],
        lobby: segment.battles.lobby ++ [extend.battles.lobby],
        total: segment.battles.total ++ [extend.battles.total]
      },

      # Used to make calculating the end of day stats easier, this will not appear in the final result
      tmp_reduction: %{
        unique_users: segment.tmp_reduction.unique_users ++ extend.tmp_reduction.unique_users,
        unique_players: segment.tmp_reduction.unique_players ++ extend.tmp_reduction.unique_players
      },

      # Daily totals
      aggregates: %{
        stats: %{
          accounts_created: 0,
          unique_users: 0,
          unique_players: 0,
          battles: 0
        },

        # Total number of minutes spent doing that across all players that day
        minutes: %{
          player: segment.aggregates.minutes.player + extend.aggregates.minutes.player,
          spectator: segment.aggregates.minutes.spectator + extend.aggregates.minutes.spectator,
          lobby: segment.aggregates.minutes.lobby + extend.aggregates.minutes.lobby,
          menu: segment.aggregates.minutes.menu + extend.aggregates.minutes.menu,
          total: segment.aggregates.minutes.total + extend.aggregates.minutes.total
        },
      },

      # The number of minutes users (combined) spent in that state during the segment
      user_counts: %{
        player: segment.user_counts.player ++ [extend.user_counts.player],
        spectator: segment.user_counts.spectator ++ [extend.user_counts.spectator],
        lobby: segment.user_counts.lobby ++ [extend.user_counts.lobby],
        menu: segment.user_counts.menu ++ [extend.user_counts.menu],
        total: segment.user_counts.total ++ [extend.user_counts.total]
      },

      # Per user minute counts for the day as a whole
      minutes_per_user: %{
        total: add_maps(segment.minutes_per_user.total, extend.minutes_per_user.total),
        player: add_maps(segment.minutes_per_user.player, extend.minutes_per_user.player),
        spectator: add_maps(segment.minutes_per_user.spectator, extend.minutes_per_user.spectator),
        lobby: add_maps(segment.minutes_per_user.lobby, extend.minutes_per_user.lobby),
        menu: add_maps(segment.minutes_per_user.menu, extend.minutes_per_user.menu)
      },
    }
  end

  # Given a list of logs, calculate a segment for them
  defp calculate_segment_parts([]), do: @empty_segment
  defp calculate_segment_parts(logs) do
    count = Enum.count(logs)

    empty_user_maps = %{
      total: %{},
      player: %{},
      spectator: %{},
      lobby: %{},
      menu: %{}
    }

    user_maps = logs
    |> Enum.reduce(empty_user_maps, fn (log, acc) ->
      %{
        total: add_maps(acc.total, Map.new(log["client"]["total"], fn userid -> {userid, 1} end)),
        player: add_maps(acc.player, Map.new(log["client"]["player"], fn userid -> {userid, 1} end)),
        spectator: add_maps(acc.spectator, Map.new(log["client"]["spectator"], fn userid -> {userid, 1} end)),
        lobby: add_maps(acc.lobby, Map.new(log["client"]["lobby"], fn userid -> {userid, 1} end)),
        menu: add_maps(acc.menu, Map.new(log["client"]["menu"], fn userid -> {userid, 1} end))
      }
    end)

    %{
      # Average battle counts per segment
      battles: %{
        in_progress: sum_keys(logs, ~w(battle in_progress))/count,
        lobby: sum_keys(logs, ~w(battle lobby))/count,
        total: sum_keys(logs, ~w(battle total))/count,
      },

      # Used to make calculating the end of day stats easier, this will not appear in the final result
      tmp_reduction: %{
        unique_users: concatenate_lists(logs, ~w(client total)),
        unique_players: concatenate_lists(logs, ~w(client player))
      },

      # Daily totals
      aggregates: %{
        stats: %{
          accounts_created: 0,
          unique_users: 0,
          unique_players: 0,
          battles: 0
        },

        # Total number of minutes spent doing that across all players that day
        minutes: %{
          player: sum_counts(logs, ~w(client players)),
          spectator: sum_counts(logs, ~w(client spectator)),
          lobby: sum_counts(logs, ~w(client lobby)),
          menu: sum_counts(logs, ~w(client menus)),
          total: sum_counts(logs, ~w(client total))
        }
      },

      # The number of minutes users (combined) spent in that state during the segment
      user_counts: %{
        player: sum_counts(logs, ~w(client players)),
        spectator: sum_counts(logs, ~w(client spectator)),
        lobby: sum_counts(logs, ~w(client lobby)),
        menu: sum_counts(logs, ~w(client menus)),
        total: sum_counts(logs, ~w(client total))
      },

      # Per user minute counts for the day as a whole
      minutes_per_user: user_maps,
    }
  end

  # Given a day log, calculate the end of day stats
  defp calculate_day_statistics(data, date) do
    tomorrow = Timex.shift(date, days: 1)

    accounts_created = Account.list_users(search: [
      inserted_after: date |> Timex.to_datetime,
      inserted_before: tomorrow |> Timex.to_datetime
    ])
    |> Enum.count

    # TODO: Calculate number of battles that took place
    battles = 0

    aggregate_stats = %{
      accounts_created: accounts_created,
      unique_users: data.tmp_reduction.unique_users |> Enum.uniq |> Enum.count,
      unique_players: data.tmp_reduction.unique_players |> Enum.uniq |> Enum.count,
      battles: battles
    }

    NestedMaps.put(data, ~w(aggregates stats)a, aggregate_stats)
    |> Map.delete(:tmp_reduction)
  end

  @spec get_logs(Date.t(), integer()) :: :ok
  defp get_logs(date, segment_number) do
    start_time = Timex.shift(date |> Timex.to_datetime(), minutes: segment_number * @segment_length)
    end_time = Timex.shift(date |> Timex.to_datetime(), minutes: (segment_number + 1) * @segment_length)

    Telemetry.list_telemetry_minute_logs(
      search: [
        between: {start_time, end_time}
      ],
      select: [:data],
      limit: @segment_length
    )
    |> Enum.map(fn l -> l.data end)
  end

  @spec clean_up_logs(Date.t()) :: :ok
  defp clean_up_logs(date) do
    # Clean up all minute logs older than X
    timestamp = Timex.shift(date, days: -@log_keep_days) |> Timex.to_datetime

    delete_query =
      from logs in Teiserver.Telemetry.TelemetryMinuteLog,
        where: logs.timestamp < ^timestamp

    Repo.delete_all(delete_query)
  end

  defp concatenate_lists(items, path) do
    items
    |> Enum.reduce([], fn (row, acc) ->
      acc ++ (NestedMaps.get(row, path) || [])
    end)
  end

  defp sum_counts(items, path) do
    items
    |> Enum.reduce(0, fn (row, acc) ->
      acc + Enum.count(NestedMaps.get(row, path) || [])
    end)
  end

  defp sum_keys(items, path) do
    items
    |> Enum.reduce(0, fn (row, acc) ->
      acc + (NestedMaps.get(row, path) || 0)
    end)
  end

  defp add_maps(m1, m2) do
    Map.merge(m1, m2, fn _k, v1, v2 -> v1 + v2 end)
  end
end
