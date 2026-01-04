defmodule Teiserver.Logging.AggregateViewLogsTask do
  @moduledoc false

  use Oban.Worker, queue: :logging

  alias Teiserver.Logging
  alias Teiserver.Logging.AggregateViewLog
  alias Teiserver.Logging.PageViewLogLib

  alias Teiserver.Repo
  import Ecto.Query, warn: false
  import Teiserver.Helper.QueryHelpers
  import Teiserver.Helper.NumberHelper, only: [c_round: 1]
  alias Decimal

  @log_keep_period 180
  # Oban.insert(Teiserver.Logging.AggregateViewLogsTask.new(%{}))
  # Teiserver.Logging.AggregateViewLogsTask.run(Timex.today() |> Timex.shift(days: -1))

  @impl Oban.Worker
  def perform(_) do
    last_date = Logging.get_last_aggregate_date()

    date =
      if last_date == nil do
        Logging.get_first_page_view_log_date()
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
        |> Teiserver.Logging.AggregateViewLogsTask.new()
        |> Oban.insert()
      end
    end

    :ok
  end

  @spec run(Date.t(), boolean()) :: :ok
  def run(date, cleanup \\ false) do
    logs = get_logs(date)

    data = %{
      "date" => date,
      "total_views" => get_total_views(logs),
      "total_uniques" => get_total_uniques(logs),
      "average_load_time" => get_average_load_time(logs),
      "guest_view_count" => get_guest_view_count(logs),
      "guest_unique_ip_count" => get_guest_unique_ip_count(logs),
      "percentile_load_time_95" => get_percentile_load_time(logs, 95) || 0,
      "percentile_load_time_99" => get_percentile_load_time(logs, 99) || 0,
      "max_load_time" => get_max_load_time(logs) || 0,
      "hourly_views" => get_hourly_views(logs),
      "hourly_uniques" => get_hourly_uniques(logs),
      "hourly_average_load_times" => get_hourly_average_load_times(logs),
      "section_data" => get_section_data(logs)
    }

    if cleanup do
      clean_up_logs(date)
    end

    # Delete old log if it exists
    delete_query =
      from logs in AggregateViewLog,
        where: logs.date == ^(date |> Timex.to_date())

    Repo.delete_all(delete_query)

    AggregateViewLog.changeset(%AggregateViewLog{}, data)
    |> Repo.insert!()

    :ok
  end

  defp get_logs(date) do
    PageViewLogLib.get_page_view_logs()
    |> PageViewLogLib.search(start_date: date)
    |> PageViewLogLib.search(end_date: Timex.shift(date, days: 1))
  end

  defp get_total_views(logs) do
    count(logs)
  end

  defp get_max_load_time(logs) do
    logs
    |> select([l], max(l.load_time))
    |> Repo.one()
  end

  defp get_total_uniques(logs) do
    logs
    |> where([l], not is_nil(l.user_id))
    |> Repo.all()
    |> Stream.map(fn l -> l.user_id end)
    |> Enum.uniq()
    |> Enum.count()
  end

  defp get_average_load_time(logs) do
    logs
    |> select([l], avg(l.load_time))
    |> Repo.one()
    |> c_round()
  end

  defp get_guest_view_count(logs) do
    logs
    |> where([l], is_nil(l.user_id))
    |> count()
  end

  defp get_guest_unique_ip_count(logs) do
    logs
    |> where([l], is_nil(l.user_id))
    |> select([l], l.ip)
    |> Repo.all()
    |> Enum.uniq()
    |> Enum.count()
  end

  defp get_hourly_views(logs) do
    logs =
      from logs in logs,
        select: {extract_hour(logs.inserted_at), count(logs.id)},
        group_by: [extract_hour(logs.inserted_at)],
        order_by: [asc: extract_hour(logs.inserted_at)]

    logs =
      Repo.all(logs)
      |> Enum.filter(fn {h, c} -> h != nil and c > 0 end)
      |> Map.new(fn {h, c} -> {c_round(h), c} end)

    Enum.map(0..24, fn h -> logs[h] || 0 end)
  end

  defp get_hourly_average_load_times(logs) do
    logs =
      from logs in logs,
        select: {extract_hour(logs.inserted_at), avg(logs.load_time)},
        group_by: [extract_hour(logs.inserted_at)],
        order_by: [asc: extract_hour(logs.inserted_at)]

    logs =
      Repo.all(logs)
      |> Enum.filter(fn {h, c} -> h != nil and c > 0 end)
      |> Map.new(fn {h, lt} -> {c_round(h), c_round(lt)} end)

    Enum.map(0..24, fn h -> logs[h] || 0 end)
  end

  defp get_hourly_uniques(logs) do
    logs =
      from logs in logs,
        select: {extract_hour(logs.inserted_at), array_agg(logs.user_id)},
        group_by: [extract_hour(logs.inserted_at)],
        order_by: [asc: extract_hour(logs.inserted_at)]

    logs =
      Repo.all(logs)
      |> Enum.filter(fn {h, c} -> h != nil and c > 0 end)
      |> Map.new(fn {h, users} -> {c_round(h), users |> Enum.uniq() |> Enum.count()} end)

    Enum.map(0..24, fn h -> logs[h] || 0 end)
  end

  # In theory I should be able to use the ntile window function but
  # I couldn't get it to work so for now I'm doing it the slow way
  defp get_percentile_load_time(logs, percentile) do
    logs =
      logs
      |> select([l], l.load_time)
      |> order_by([l], asc: l.load_time)

    # The min is to prevent it having no value if there are too few logs
    number = max(count(logs), 1)

    percentile_spot =
      round(number / 100 * percentile)
      |> min(number - 1)

    logs
    |> offset([l], ^percentile_spot)
    |> limit(1)
    |> Repo.one()
  end

  defp get_section_data(base_logs) do
    grouped_logs =
      from logs in base_logs,
        select: {
          logs.section,
          count(logs.id),
          avg(logs.load_time),
          array_agg(logs.user_id)
        },
        group_by: [logs.section]

    grouped_logs
    |> Repo.all()
    |> Map.new(fn {section, count, load_time, users} ->
      {section,
       %{
         count: count,
         load_time: c_round(load_time),
         users: users |> Enum.uniq()
       }}
    end)
  end

  defp clean_up_logs(date) do
    PageViewLogLib.get_page_view_logs()
    |> PageViewLogLib.search(end_date: Timex.shift(date, days: -@log_keep_period))
    |> Repo.delete_all()
  end
end
