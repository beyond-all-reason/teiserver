defmodule Barserver.Logging.Tasks.PersistServerQuarterTask do
  @moduledoc false
  use Oban.Worker, queue: :teiserver
  alias Barserver.Logging
  alias Barserver.Logging.ServerDayLogLib
  import Ecto.Query, warn: false

  @impl Oban.Worker
  @spec perform(any) :: :ok
  def perform(_) do
    log =
      case Logging.get_last_server_quarter_log() do
        nil ->
          perform_first_time()

        date ->
          perform_standard(date)
      end

    if log != nil do
      %{}
      |> Barserver.Logging.Tasks.PersistServerQuarterTask.new()
      |> Oban.insert()
    end

    :ok
  end

  # For when there are no existing logs
  # we need to ensure the earliest log is from last quarter, not this quarter
  defp perform_first_time() do
    first_logs =
      Logging.list_server_day_logs(
        order: "Oldest first",
        limit: 1
      )

    case first_logs do
      [log] ->
        today_quarter = Timex.today() |> Timex.quarter()
        log_quarter = log.date |> Timex.quarter()

        if log.date.year < Timex.today().year or log_quarter < today_quarter do
          logs =
            Logging.list_server_day_logs(
              search: [
                start_date: Timex.beginning_of_quarter(log.date),
                end_date: Timex.end_of_quarter(log.date)
              ],
              limit: 100
            )

          user_activity_logs =
            Logging.list_user_activity_day_logs(
              search: [
                start_date: Timex.beginning_of_quarter(log.date),
                end_date: Timex.end_of_quarter(log.date)
              ],
              limit: 100
            )

          data =
            logs
            |> Enum.zip(user_activity_logs)
            |> ServerDayLogLib.aggregate_day_logs()

          {:ok, _} =
            Logging.create_server_quarter_log(%{
              year: log.date.year,
              quarter: log_quarter,
              date: Timex.beginning_of_quarter(log.date),
              data: data
            })
        end

      _ ->
        nil
    end
  end

  # For when we have an existing log
  defp perform_standard(log_date) do
    new_date = Timex.shift(log_date, months: 3)

    new_quarter = new_date |> Timex.quarter()
    today_quarter = Timex.today() |> Timex.quarter()

    if new_date.year < Timex.today().year or new_quarter < today_quarter do
      logs =
        Logging.list_server_day_logs(
          search: [
            start_date: Timex.beginning_of_quarter(new_date),
            end_date: Timex.end_of_quarter(new_date)
          ],
          limit: 100
        )

      user_activity_logs =
        Logging.list_user_activity_day_logs(
          search: [
            start_date: Timex.beginning_of_quarter(new_date),
            end_date: Timex.end_of_quarter(new_date)
          ],
          limit: 100
        )

      data =
        logs
        |> Enum.zip(user_activity_logs)
        |> ServerDayLogLib.aggregate_day_logs()

      {:ok, _} =
        Logging.create_server_quarter_log(%{
          year: new_date.year,
          quarter: new_quarter,
          date: new_date,
          data: data
        })
    else
      nil
    end
  end

  @spec quarter_so_far() :: map()
  def quarter_so_far() do
    now = Timex.now()

    user_activity_logs =
      Logging.list_user_activity_day_logs(
        search: [
          start_date: Timex.beginning_of_quarter(now)
        ],
        limit: 100
      )

    Logging.list_server_day_logs(
      search: [
        start_date: Timex.beginning_of_quarter(now)
      ],
      limit: 100
    )
    |> Enum.zip(user_activity_logs)
    |> ServerDayLogLib.aggregate_day_logs()
    |> Jason.encode!()
    |> Jason.decode!()

    # We encode and decode so it's the same format as in the database
  end
end
