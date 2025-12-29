defmodule Teiserver.Logging.Tasks.PersistServerDayTask do
  @moduledoc false
  use Oban.Worker, queue: :teiserver
  alias Teiserver.{Account, Logging, Battle}

  alias Teiserver.Repo
  import Ecto.Query, warn: false

  @log_keep_days 30
  # Minutes
  @segment_length 60
  @segment_count div(1440, @segment_length) - 1

  @client_states ~w(lobby menu player spectator total)a

  # [] List means 15 minute segments
  # %{} Dict means total for the day for that key
  # 0 Integer means sum or average
  @empty_log %{
    # Average battle counts per segment
    battles: %{
      in_progress: [],
      lobby: [],
      total: []
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
        # Currently we can't track when a battle starts and ends correctly
        battles: 0
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
    average_user_counts: %{
      player: [],
      spectator: [],
      lobby: [],
      menu: [],
      total: []
    },
    peak_user_counts: %{
      player: [],
      spectator: [],
      lobby: [],
      menu: [],
      total: []
    },

    # Per user minute counts for the day as a whole
    old_minutes_per_user: %{
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
      total: 0
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
        # Currently we can't track when a battle starts and ends correctly
        battles: 0
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
    average_user_counts: %{
      player: 0,
      spectator: 0,
      lobby: 0,
      menu: 0,
      total: 0
    },
    peak_user_counts: %{
      player: 0,
      spectator: 0,
      lobby: 0,
      menu: 0,
      total: 0
    },

    # Per user minute counts for the day as a whole
    old_minutes_per_user: %{
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
    last_date = Logging.get_last_server_day_log()

    date =
      if last_date == nil do
        Logging.get_first_telemetry_minute_datetime()
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
        |> Teiserver.Logging.Tasks.PersistServerDayTask.new()
        |> Oban.insert()
      end
    end

    :ok
  end

  @spec run(Date.t(), boolean()) :: :ok
  def run(date, cleanup) do
    data =
      0..@segment_count
      |> Enum.reduce(@empty_log, fn segment_number, segment ->
        logs = get_logs(date, segment_number)
        extend_segment(segment, logs)
      end)
      |> calculate_day_statistics(date)
      |> add_matches(date)
      |> add_telemetry(date)

    if cleanup do
      clean_up_logs(date)
    end

    # Delete old log if it exists
    delete_query =
      from logs in Teiserver.Logging.ServerDayLog,
        where: logs.date == ^(date |> Timex.to_date())

    Repo.delete_all(delete_query)

    Logging.create_server_day_log(%{
      date: date,
      data: data
    })

    :ok
  end

  def today_so_far() do
    date = Timex.today()

    0..@segment_count
    |> Enum.reduce(@empty_log, fn segment_number, segment ->
      logs = get_logs(date, segment_number)
      extend_segment(segment, logs)
    end)
    |> calculate_day_statistics(date)
    |> add_telemetry(date)
    |> Jason.encode!()
    |> Jason.decode!()

    # We encode and decode so it's the same format as in the database
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
        unique_players:
          segment.tmp_reduction.unique_players ++ extend.tmp_reduction.unique_players
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
        }
      },

      # The number of minutes users (combined) spent in that state during the segment
      average_user_counts: %{
        player: segment.average_user_counts.player ++ [extend.average_user_counts.player],
        spectator:
          segment.average_user_counts.spectator ++ [extend.average_user_counts.spectator],
        lobby: segment.average_user_counts.lobby ++ [extend.average_user_counts.lobby],
        menu: segment.average_user_counts.menu ++ [extend.average_user_counts.menu],
        total: segment.average_user_counts.total ++ [extend.average_user_counts.total]
      },
      peak_user_counts: %{
        player: segment.peak_user_counts.player ++ [extend.peak_user_counts.player],
        spectator: segment.peak_user_counts.spectator ++ [extend.peak_user_counts.spectator],
        lobby: segment.peak_user_counts.lobby ++ [extend.peak_user_counts.lobby],
        menu: segment.peak_user_counts.menu ++ [extend.peak_user_counts.menu],
        total: segment.peak_user_counts.total ++ [extend.peak_user_counts.total]
      },

      # Per user minute counts for the day as a whole
      old_minutes_per_user: %{
        total: add_maps(segment.old_minutes_per_user.total, extend.old_minutes_per_user.total),
        player: add_maps(segment.old_minutes_per_user.player, extend.old_minutes_per_user.player),
        spectator:
          add_maps(segment.old_minutes_per_user.spectator, extend.old_minutes_per_user.spectator),
        lobby: add_maps(segment.old_minutes_per_user.lobby, extend.old_minutes_per_user.lobby),
        menu: add_maps(segment.old_minutes_per_user.menu, extend.old_minutes_per_user.menu)
      }
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

    user_maps =
      logs
      |> Enum.reduce(empty_user_maps, fn log, acc ->
        %{
          total:
            add_maps(
              acc.total,
              Map.new(log["client"]["total"] || [], fn userid -> {userid, 1} end)
            ),
          player:
            add_maps(
              acc.player,
              Map.new(log["client"]["player"] || [], fn userid -> {userid, 1} end)
            ),
          spectator:
            add_maps(
              acc.spectator,
              Map.new(log["client"]["spectator"] || [], fn userid -> {userid, 1} end)
            ),
          lobby:
            add_maps(
              acc.lobby,
              Map.new(log["client"]["lobby"] || [], fn userid -> {userid, 1} end)
            ),
          menu:
            add_maps(acc.menu, Map.new(log["client"]["menu"] || [], fn userid -> {userid, 1} end))
        }
      end)

    %{
      # Average battle counts per segment
      battles: %{
        in_progress: sum_keys(logs, ~w(battle in_progress)) / count,
        lobby: sum_keys(logs, ~w(battle lobby)) / count,
        total: sum_keys(logs, ~w(battle total)) / count
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
          player: sum_counts(logs, ~w(client player)),
          spectator: sum_counts(logs, ~w(client spectator)),
          lobby: sum_counts(logs, ~w(client lobby)),
          menu: sum_counts(logs, ~w(client menu)),
          total: sum_counts(logs, ~w(client total))
        }
      },

      # The number of minutes users (combined) spent in that state during the segment
      average_user_counts: %{
        player: sum_counts(logs, ~w(client player)) / count,
        spectator: sum_counts(logs, ~w(client spectator)) / count,
        lobby: sum_counts(logs, ~w(client lobby)) / count,
        menu: sum_counts(logs, ~w(client menu)) / count,
        total: sum_counts(logs, ~w(client total)) / count
      },
      peak_user_counts: %{
        player: max_counts(logs, ~w(client player)),
        spectator: max_counts(logs, ~w(client spectator)),
        lobby: max_counts(logs, ~w(client lobby)),
        menu: max_counts(logs, ~w(client menu)),
        total: max_counts(logs, ~w(client total))
      },

      # Per user minute counts for the day as a whole
      old_minutes_per_user: user_maps
    }
  end

  # Given a day log, calculate the end of day stats
  defp calculate_day_statistics(data, date) do
    tomorrow = Timex.shift(date, days: 1)

    accounts_created =
      Account.list_users(
        search: [
          inserted_after: date |> Timex.to_datetime(),
          inserted_before: tomorrow |> Timex.to_datetime(),
          smurf_of: false
        ],
        limit: :infinity
      )
      |> Enum.count()

    # credo:disable-for-next-line Credo.Check.Design.TagTODO
    # TODO: Calculate number of battles that took place
    battles = 0

    # Calculate peak users across the day
    peak_user_counts =
      @client_states
      |> Map.new(fn state_key ->
        counts = data.peak_user_counts[state_key]
        {state_key, Enum.max(counts)}
      end)

    aggregate_stats = %{
      accounts_created: accounts_created,
      unique_users: data.tmp_reduction.unique_users |> Enum.uniq() |> Enum.count(),
      unique_players: data.tmp_reduction.unique_players |> Enum.uniq() |> Enum.count(),
      battles: battles,
      peak_user_counts: peak_user_counts
    }

    put_in(data, ~w(aggregates stats)a, aggregate_stats)
    |> Map.delete(:tmp_reduction)
  end

  @spec get_logs(Date.t(), integer()) :: list()
  defp get_logs(date, segment_number) do
    start_time =
      Timex.shift(date |> Timex.to_datetime(), minutes: segment_number * @segment_length)

    end_time =
      Timex.shift(date |> Timex.to_datetime(), minutes: (segment_number + 1) * @segment_length)

    Logging.list_server_minute_logs(
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
    # Clean up all minute logs older than X days
    before_timestamp =
      Timex.shift(date, days: -@log_keep_days)
      |> Timex.to_datetime()

    query = """
          DELETE FROM teiserver_server_minute_logs WHERE timestamp < $1
    """

    Ecto.Adapters.SQL.query!(Repo, query, [before_timestamp])
  end

  defp concatenate_lists(items, path) do
    items
    |> Enum.reduce([], fn row, acc ->
      acc ++ (get_in(row, path) || [])
    end)
  end

  defp max_counts(items, path) do
    items
    |> Enum.reduce(0, fn row, acc ->
      max(acc, Enum.count(get_in(row, path) || []))
    end)
  end

  defp sum_counts(items, path) do
    items
    |> Enum.reduce(0, fn row, acc ->
      acc + Enum.count(get_in(row, path) || [])
    end)
  end

  defp sum_keys(items, path) do
    items
    |> Enum.reduce(0, fn row, acc ->
      acc + (get_in(row, path) || 0)
    end)
  end

  defp add_maps(m1, nil), do: m1

  defp add_maps(m1, m2) do
    Map.merge(m1, m2, fn _k, v1, v2 -> v1 + v2 end)
  end

  @match_blank_acc %{
    counts: %{
      total: 0,
      scavengers: 0,
      raptors: 0,
      bots: 0,
      duel: 0,
      team: 0,
      small_team: 0,
      large_team: 0,
      ffa: 0,
      team_ffa: 0,
      passworded: 0
    },
    maps: %{},
    team_sizes: %{},
    durations: %{},

    # Temp values, we drop them later
    match_durations: []
  }
  @drop_keys [:match_durations]

  defp add_matches(stats, date) do
    Map.put(stats, :matches, get_matches_from_day(date))
  end

  @spec get_matches_from_day(Date.t()) :: map()
  defp get_matches_from_day(the_date) do
    the_date = Timex.to_datetime(the_date)

    battle_minimum_seconds =
      Application.get_env(:teiserver, Teiserver)[:retention][:battle_minimum_seconds]

    Battle.list_matches(
      search: [
        inserted_after: the_date,
        inserted_before: Timex.shift(the_date, days: 1),
        of_interest: true
      ],
      limit: :infinity
    )
    |> Stream.filter(fn match ->
      Timex.diff(match.finished, match.started, :second) >= battle_minimum_seconds
    end)
    |> Enum.reduce(@match_blank_acc, &add_match/2)
    |> second_pass()
    |> Map.drop(@drop_keys)
  end

  defp second_pass(%{counts: %{total: 0}} = stats), do: stats

  defp second_pass(stats) do
    durations = stats.match_durations

    Map.merge(stats, %{
      durations: %{
        total: Enum.sum(durations),
        average: round(Enum.sum(durations) / stats.counts[:total]),
        above_5: Enum.count(durations, fn d -> d >= 5 * 60 end),
        above_10: Enum.count(durations, fn d -> d >= 10 * 60 end),
        above_15: Enum.count(durations, fn d -> d >= 15 * 60 end),
        above_20: Enum.count(durations, fn d -> d >= 20 * 60 end),
        above_25: Enum.count(durations, fn d -> d >= 25 * 60 end),
        above_30: Enum.count(durations, fn d -> d >= 30 * 60 end),
        above_35: Enum.count(durations, fn d -> d >= 35 * 60 end),
        above_40: Enum.count(durations, fn d -> d >= 40 * 60 end),
        above_45: Enum.count(durations, fn d -> d >= 45 * 60 end),
        above_50: Enum.count(durations, fn d -> d >= 50 * 60 end),
        above_55: Enum.count(durations, fn d -> d >= 55 * 60 end),
        above_60: Enum.count(durations, fn d -> d >= 60 * 60 end)
      }
    })
  end

  defp add_match(match, acc) do
    # First, we increment the game count
    game_type =
      case match.game_type do
        "PvE" -> :scavengers
        "Scavengers" -> :scavengers
        "Raptors" -> :raptors
        "Bots" -> :bots
        "Duel" -> :duel
        "Team" -> :team
        "Small Team" -> :small_team
        "Large Team" -> :large_team
        "FFA" -> :ffa
        "Team FFA" -> :team_ffa
      end

    acc = Map.put(acc, :counts, Map.put(acc.counts, :total, acc.counts[:total] + 1))
    acc = Map.put(acc, :counts, Map.put(acc.counts, game_type, acc.counts[game_type] + 1))

    # If passworded increment that too
    acc =
      if match.passworded do
        Map.put(acc, :counts, Map.put(acc.counts, :passworded, acc.counts[:passworded] + 1))
      else
        acc
      end

    # Now the maps
    acc = Map.put(acc, :maps, Map.put(acc.maps, match.map, Map.get(acc.maps, match.map, 0) + 1))

    # Team size counts
    acc =
      Map.put(
        acc,
        :team_sizes,
        Map.put(acc.team_sizes, match.team_size, Map.get(acc.team_sizes, match.team_size, 0) + 1)
      )

    # Durations
    duration = Timex.diff(match.finished, match.started, :second)
    acc = Map.put(acc, :match_durations, [duration | acc.match_durations])

    # Skill

    acc
  end

  defp add_telemetry(stats, date) do
    start_date = date |> Timex.to_datetime()
    end_date = date |> Timex.shift(days: 1) |> Timex.to_datetime()

    complex_client_data = run_event_query("complex", "client", start_date, end_date)
    simple_client_data = run_event_query("simple", "client", start_date, end_date)

    complex_anon_data = run_anon_event_query("complex", start_date, end_date)
    simple_anon_data = run_anon_event_query("simple", start_date, end_date)

    complex_server_data = run_event_query("complex", "server", start_date, end_date)
    simple_server_data = run_event_query("simple", "server", start_date, end_date)

    complex_lobby_data = run_event_query("complex", "lobby", start_date, end_date)
    simple_lobby_data = run_event_query("simple", "lobby", start_date, end_date)

    complex_match_data = run_match_event_query("complex", start_date, end_date)
    simple_match_data = run_match_event_query("simple", start_date, end_date)

    infologs = count_infologs(start_date, end_date)

    Map.put(stats, :events, %{
      complex_client: complex_client_data,
      simple_client: simple_client_data,
      complex_anon: complex_anon_data,
      simple_anon: simple_anon_data,
      complex_server: complex_server_data,
      simple_server: simple_server_data,
      complex_lobby: complex_lobby_data,
      simple_lobby: simple_lobby_data,
      complex_match: complex_match_data,
      simple_match: simple_match_data,
      infologs: infologs
    })
  end

  defp run_event_query(complexity, section, start_date, end_date) do
    query =
      """
        SELECT
          t.name,
          COUNT(e)
        FROM
          telemetry_{mode}_events e
        JOIN
          telemetry_{mode}_event_types t ON e.event_type_id = t.id
        WHERE
          e.timestamp BETWEEN $1 AND $2
        GROUP BY
          t.name
      """
      |> String.replace(
        "{mode}",
        "#{complexity}_#{section}"
      )

    case Ecto.Adapters.SQL.query(Repo, query, [start_date, end_date]) do
      {:ok, results} ->
        results.rows
        |> Map.new(fn [key, value] -> {key, value} end)

      {a, b} ->
        raise "ERR: #{a}, #{b}"
    end
  end

  defp run_anon_event_query(complexity, start_date, end_date) do
    query =
      """
        SELECT
          t.name,
          COUNT(e)
        FROM
          telemetry_{complexity}_anon_events e
        JOIN
          telemetry_{complexity}_client_event_types t ON e.event_type_id = t.id
        WHERE
          e.timestamp BETWEEN $1 AND $2
        GROUP BY
          t.name
      """
      |> String.replace(
        "{complexity}",
        complexity
      )

    case Ecto.Adapters.SQL.query(Repo, query, [start_date, end_date]) do
      {:ok, results} ->
        results.rows
        |> Map.new(fn [key, value] -> {key, value} end)

      {a, b} ->
        raise "ERR: #{a}, #{b}"
    end
  end

  defp run_match_event_query(complexity, start_date, end_date) do
    query =
      """
        SELECT
          t.name,
          COUNT(e)
        FROM
          telemetry_{complexity}_match_events e
        JOIN
          telemetry_{complexity}_match_event_types t ON e.event_type_id = t.id
        JOIN
          teiserver_battle_matches m ON m.id = e.match_id
        WHERE
          m.started BETWEEN $1 AND $2
        GROUP BY
          t.name;
      """
      |> String.replace(
        "{complexity}",
        complexity
      )

    case Ecto.Adapters.SQL.query(Repo, query, [start_date, end_date]) do
      {:ok, results} ->
        results.rows
        |> Map.new(fn [key, value] -> {key, value} end)

      {a, b} ->
        raise "ERR: #{a}, #{b}"
    end
  end

  defp count_infologs(start_date, end_date) do
    query = """
      SELECT
        l.log_type,
        COUNT(*)
      FROM telemetry_infologs l
      WHERE
        l.timestamp BETWEEN $1 AND $2
      GROUP BY
        l.log_type;
    """

    count_map =
      case Ecto.Adapters.SQL.query(Repo, query, [start_date, end_date]) do
        {:ok, results} ->
          results.rows
          |> Map.new(fn [key, value] -> {key, value} end)

        {a, b} ->
          raise "ERR: #{a}, #{b}"
      end

    total =
      count_map
      |> Map.values()
      |> Enum.sum()

    Map.put(count_map, "total", total)
  end
end
