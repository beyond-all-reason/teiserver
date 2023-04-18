defmodule Teiserver.Telemetry.Tasks.PersistUserActivityDayTask do
  use Oban.Worker, queue: :teiserver
  alias Teiserver.{Telemetry, Battle}
  alias Central.Account

  alias Central.Repo
  import Ecto.Query, warn: false
  import Central.Helpers.TimexHelper, only: [date_to_str: 2]

  @client_states ~w(lobby menu player spectator total)a

  @impl Oban.Worker
  @spec perform(any) :: :ok
  def perform(_) do
  #   last_date = Telemetry.get_last_server_day_log()

  #   date =
  #     if last_date == nil do
  #       Telemetry.get_first_telemetry_minute_datetime()
  #       |> Timex.to_date()
  #     else
  #       last_date
  #       |> Timex.shift(days: 1)
  #     end

  #   if Timex.compare(date, Timex.today()) == -1 do
  #     run(date, cleanup: true)

  #     new_date = Timex.shift(date, days: 1)

  #     if Timex.compare(new_date, Timex.today()) == -1 do
  #       %{}
  #       |> Teiserver.Telemetry.Tasks.PersistServerDayTask.new()
  #       |> Oban.insert()
  #     end
  #   end

    :ok
  end

  # @spec run(%Date{}, boolean()) :: :ok
  # def run(date, cleanup) do
  #   data =
  #     0..@segment_count
  #     |> Enum.reduce(@empty_log, fn segment_number, segment ->
  #       logs = get_logs(date, segment_number)
  #       extend_segment(segment, logs)
  #     end)
  #     |> calculate_day_statistics(date)
  #     |> add_matches(date)
  #     |> add_telemetry(date)

  #   if cleanup do
  #     clean_up_logs(date)
  #   end

  #   # Delete old log if it exists
  #   delete_query =
  #     from logs in Teiserver.Telemetry.ServerDayLog,
  #       where: logs.date == ^(date |> Timex.to_date())

  #   Repo.delete_all(delete_query)

  #   Telemetry.create_server_day_log(%{
  #     date: date,
  #     data: data
  #   })

  #   :ok
  # end

  # def today_so_far() do
  #   date = Timex.today()

  #   0..@segment_count
  #   |> Enum.reduce(@empty_log, fn segment_number, segment ->
  #     logs = get_logs(date, segment_number)
  #     extend_segment(segment, logs)
  #   end)
  #   |> calculate_day_statistics(date)
  #   |> add_telemetry(date)
  #   |> Jason.encode!()
  #   |> Jason.decode!()

  #   # We encode and decode so it's the same format as in the database
  # end


  # @spec get_logs(Date.t(), integer()) :: list()
  # defp get_logs(date, segment_number) do
  #   start_time =
  #     Timex.shift(date |> Timex.to_datetime(), minutes: segment_number * @segment_length)

  #   end_time =
  #     Timex.shift(date |> Timex.to_datetime(), minutes: (segment_number + 1) * @segment_length)

  #   Telemetry.list_server_minute_logs(
  #     search: [
  #       between: {start_time, end_time}
  #     ],
  #     select: [:data],
  #     limit: @segment_length
  #   )
  #   |> Enum.map(fn l -> l.data end)
  # end
end
