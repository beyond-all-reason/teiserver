defmodule Teiserver.Logging.Tasks.PersistMatchMonthTask do
  use Oban.Worker, queue: :teiserver
  alias Teiserver.Logging
  import Ecto.Query, warn: false

  @sections ~w(bots duel ffa raptors scavengers team small_team large_team totals)

  # [] List means 1 day segments
  # %{} Dict means total for the month of that key
  # 0 Integer means sum or average
  @empty_segment %{
    aggregate: %{
      total_count: 0,
      total_duration_seconds: 0,
      weighted_count: 0
    },
    duration: %{},
    maps: %{},
    matches_per_hour: %{},
    team_sizes: %{}
  }

  @empty_result Map.new(@sections, fn s ->
                  {s, @empty_segment}
                end)

  @impl Oban.Worker
  @spec perform(any) :: :ok
  def perform(_) do
    log =
      case Logging.get_last_match_month_log() do
        nil ->
          perform_first_time()

        {year, month} ->
          {y, m} = next_month({year, month})
          perform_standard(y, m)
      end

    if log != nil do
      %{}
      |> Teiserver.Logging.Tasks.PersistMatchMonthTask.new()
      |> Oban.insert()
    end

    :ok
  end

  # For when there are no existing logs
  # we need to ensure the earliest log is from last month, not this month
  defp perform_first_time() do
    first_logs =
      Logging.list_match_day_logs(
        order: "Oldest first",
        limit: 1
      )

    case first_logs do
      [log] ->
        today = Timex.today()

        if log.date.year < today.year or log.date.month < today.month do
          logs =
            Logging.list_match_day_logs(
              search: [
                start_date: Timex.beginning_of_month(log.date),
                end_date: Timex.end_of_month(log.date)
              ]
            )

          data = run(logs)

          Logging.create_match_month_log(%{
            year: log.date.year,
            month: log.date.month,
            data: data
          })
        end

      _ ->
        nil
    end
  end

  # For when we have an existing log
  defp perform_standard(year, month) do
    today = Timex.today()

    if year < today.year or month < today.month do
      now = Timex.Date.new!(year, month, 1)

      logs =
        Logging.list_match_day_logs(
          search: [
            start_date: Timex.beginning_of_month(now),
            end_date: Timex.end_of_month(now)
          ]
        )

      data = run(logs)

      Logging.create_match_month_log(%{
        year: year,
        month: month,
        data: data
      })
    else
      nil
    end
  end

  @spec run(list()) :: map()
  def run(logs) do
    logs
    |> Enum.reduce(@empty_result, fn log, acc ->
      extend_segment(acc, log)
    end)
    |> post_process()
  end

  @spec month_so_far() :: map()
  def month_so_far() do
    now = Timex.now()

    Logging.list_match_day_logs(
      search: [
        start_date: Timex.beginning_of_month(now)
      ]
    )
    |> Enum.reduce(@empty_result, fn log, acc ->
      extend_segment(acc, log)
    end)
    |> post_process()
    |> Jason.encode!()
    |> Jason.decode!()

    # We encode and decode so it's the same format as in the database
  end

  # Given an existing segment and a batch of logs, calculate the segment and add them together
  defp extend_segment(existing, %{data: data} = _log) do
    @sections
    |> Map.new(fn s ->
      {s, extend_sub_section(existing[s], data[s])}
    end)
  end

  defp extend_sub_section(existing, data) do
    %{
      aggregate: %{
        total_count: existing.aggregate.total_count + (data["aggregate"]["total_count"] || 0),
        total_duration_seconds:
          existing.aggregate.total_duration_seconds +
            (data["aggregate"]["total_duration_seconds"] || 0),
        weighted_count:
          existing.aggregate.weighted_count + (data["aggregate"]["weighted_count"] || 0)
      },
      duration: sum_maps(existing.duration, data["duration"] || 0),
      maps: sum_maps(existing.maps, data["maps"] || 0),
      matches_per_hour: sum_maps(existing.matches_per_hour, data["matches_per_hour"] || 0),
      team_sizes: sum_maps(existing.team_sizes, data["team_sizes"] || 0)
    }
  end

  defp post_process(data) do
    @sections
    |> Map.new(fn s ->
      {s, post_process_section(data[s])}
    end)
  end

  defp post_process_section(data) do
    mean_duration_seconds =
      (data.aggregate.total_duration_seconds / max(data.aggregate.total_count, 1))
      |> round()

    data
    |> put_in(~w(aggregate mean_duration_seconds)a, mean_duration_seconds)
  end

  defp sum_maps(m1, m2) do
    keys =
      (Map.keys(m1) ++ Map.keys(m2))
      |> Enum.uniq()

    keys
    |> Map.new(fn key ->
      {key, Map.get(m1, key, 0) + Map.get(m2, key, 0)}
    end)
  end

  defp next_month({year, 12}), do: {year + 1, 1}
  defp next_month({year, month}), do: {year, month + 1}
end
