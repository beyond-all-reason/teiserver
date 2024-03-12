defmodule Barserver.Logging.Tasks.PersistServerWeekTask do
  @moduledoc false
  use Oban.Worker, queue: :teiserver
  alias Barserver.Logging
  alias Barserver.Logging.ServerDayLogLib
  import Ecto.Query, warn: false

  @impl Oban.Worker
  @spec perform(any) :: :ok
  def perform(_) do
    log =
      case Logging.get_last_server_week_log() do
        nil ->
          perform_first_time()

        date ->
          perform_standard(date)
      end

    if log != nil do
      %{}
      |> Barserver.Logging.Tasks.PersistServerWeekTask.new()
      |> Oban.insert()
    end

    :ok
  end

  # For when there are no existing logs
  # we need to ensure the earliest log is from last week, not this week
  defp perform_first_time() do
    first_logs =
      Logging.list_server_day_logs(
        order: "Oldest first",
        limit: 1
      )

    case first_logs do
      [log] ->
        {today_year, today_week} = Timex.today() |> Timex.iso_week()
        {log_year, log_week} = log.date |> Timex.iso_week()

        if log_year < today_year or log_week < today_week do
          logs =
            Logging.list_server_day_logs(
              search: [
                start_date: Timex.beginning_of_week(log.date),
                end_date: Timex.end_of_week(log.date)
              ]
            )

          user_activity_logs =
            Logging.list_user_activity_day_logs(
              search: [
                start_date: Timex.beginning_of_week(log.date),
                end_date: Timex.end_of_week(log.date)
              ]
            )

          data =
            logs
            |> Enum.zip(user_activity_logs)
            |> ServerDayLogLib.aggregate_day_logs()

          {:ok, _} =
            Logging.create_server_week_log(%{
              year: log_year,
              week: log_week,
              date: Timex.beginning_of_week(log.date),
              data: data
            })
        end

      _ ->
        nil
    end
  end

  # For when we have an existing log
  defp perform_standard(log_date) do
    new_date = Timex.shift(log_date, days: 7)

    {new_year, new_week} = new_date |> Timex.iso_week()
    {today_year, today_week} = Timex.today() |> Timex.iso_week()

    if new_year < today_year or new_week < today_week do
      logs =
        Logging.list_server_day_logs(
          search: [
            start_date: Timex.beginning_of_week(new_date),
            end_date: Timex.end_of_week(new_date)
          ]
        )

      user_activity_logs =
        Logging.list_user_activity_day_logs(
          search: [
            start_date: Timex.beginning_of_week(new_date),
            end_date: Timex.end_of_week(new_date)
          ]
        )

      data =
        logs
        |> Enum.zip(user_activity_logs)
        |> ServerDayLogLib.aggregate_day_logs()

      {:ok, _} =
        Logging.create_server_week_log(%{
          year: new_year,
          week: new_week,
          date: new_date,
          data: data
        })
    else
      nil
    end
  end

  @spec week_so_far() :: map()
  def week_so_far() do
    now = Timex.now()

    user_activity_logs =
      Logging.list_user_activity_day_logs(
        search: [
          start_date: Timex.beginning_of_week(now)
        ]
      )

    Logging.list_server_day_logs(
      search: [
        start_date: Timex.beginning_of_week(now)
      ]
    )
    |> Enum.zip(user_activity_logs)
    |> ServerDayLogLib.aggregate_day_logs()
    |> Jason.encode!()
    |> Jason.decode!()

    # We encode and decode so it's the same format as in the database
  end
end
