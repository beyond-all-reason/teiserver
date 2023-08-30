defmodule Teiserver.Logging.Tasks.PersistServerYearTask do
  @moduledoc false
  use Oban.Worker, queue: :teiserver
  alias Teiserver.Logging
  alias Teiserver.Logging.ServerDayLogLib
  import Ecto.Query, warn: false

  @impl Oban.Worker
  @spec perform(any) :: :ok
  def perform(_) do
    log =
      case Logging.get_last_server_year_log() do
        nil ->
          perform_first_time()

        date ->
          perform_standard(date)
      end

    if log != nil do
      %{}
      |> Teiserver.Logging.Tasks.PersistServerYearTask.new()
      |> Oban.insert()
    end

    :ok
  end

  # For when there are no existing logs
  # we need to ensure the earliest log is from last year, not this year
  defp perform_first_time() do
    first_logs =
      Logging.list_server_day_logs(
        order: "Oldest first",
        limit: 1
      )

    case first_logs do
      [log] ->
        log_year = log.date.year

        if log_year < Timex.today().year do
          logs =
            Logging.list_server_day_logs(
              search: [
                start_date: Timex.beginning_of_year(log.date),
                end_date: Timex.end_of_year(log.date)
              ]
            )

          data = ServerDayLogLib.aggregate_day_logs(logs)

          {:ok, _} =
            Logging.create_server_year_log(%{
              year: log_year,
              date: Timex.beginning_of_year(log.date),
              data: data
            })
        end

      _ ->
        nil
    end
  end

  # For when we have an existing log
  defp perform_standard(log_date) do
    new_date = Timex.shift(log_date, years: 1)

    today_year = Timex.today().year

    if new_date.year < today_year do
      logs =
        Logging.list_server_day_logs(
          search: [
            start_date: Timex.beginning_of_year(new_date),
            end_date: Timex.end_of_year(new_date)
          ]
        )

      data = ServerDayLogLib.aggregate_day_logs(logs)

      {:ok, _} =
        Logging.create_server_year_log(%{
          year: new_date.year,
          date: new_date,
          data: data
        })
    else
      nil
    end
  end

  @spec year_so_far() :: map()
  def year_so_far() do
    now = Timex.now()

    user_activity_logs = Logging.list_user_activity_day_logs(
      search: [
        start_date: Timex.beginning_of_year(now)
      ]
    )

    Logging.list_server_day_logs(
      search: [
        start_date: Timex.beginning_of_year(now)
      ]
    )
    |> Enum.zip(user_activity_logs)
    |> ServerDayLogLib.aggregate_day_logs()
    |> Jason.encode!()
    |> Jason.decode!()

    # We encode and decode so it's the same format as in the database
  end
end
