defmodule Teiserver.Telemetry.Tasks.PersistMatchMonthTask do
  use Oban.Worker, queue: :teiserver
  alias Teiserver.Telemetry
  alias Teiserver.Battle.Tasks.BreakdownMatchDataTask

  alias Central.Repo
  import Ecto.Query, warn: false

  @impl Oban.Worker
  @spec perform(any) :: :ok
  def perform(_) do
    log = case Telemetry.get_last_match_month_log() do
      nil ->
        perform_first_time()

      {year, month} ->
        {y, m} = next_month({year, month})
        perform_standard(y, m)
    end

    if log != nil do
      %{}
      |> Teiserver.Telemetry.Tasks.PersistMatchMonthTask.new()
      |> Oban.insert()
    end

    :ok
  end

  # For when there are no existing logs
  # we need to ensure the earliest log is from last month, not this month
  defp perform_first_time() do
    first_logs = Telemetry.list_match_day_logs(
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
    start_date = Timex.beginning_of_month(now)
    end_date = Timex.end_of_month(now)

    data = BreakdownMatchDataTask.perform(start_date, end_date)

    # Delete old log if it exists
    delete_query =
      from logs in Teiserver.Telemetry.MatchMonthLog,
        where: logs.year == ^year,
        where: logs.month == ^month

    Repo.delete_all(delete_query)

    Telemetry.create_match_month_log(%{
      year: year,
      month: month,
      data: data
    })
  end

  defp next_month({year, 12}), do: {year+1, 1}
  defp next_month({year, month}), do: {year, month+1}
end
