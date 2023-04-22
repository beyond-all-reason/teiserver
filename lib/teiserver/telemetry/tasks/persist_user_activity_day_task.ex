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
    last_date = Telemetry.get_last_user_activity_day_log()

    date =
      if last_date == nil do
        Telemetry.get_first_telemetry_minute_datetime()
        |> Timex.to_date()
      else
        last_date
        |> Timex.shift(days: 1)
      end

    if Timex.compare(date, Timex.today()) == -1 do
      run(date)

      new_date = Timex.shift(date, days: 1)

      if Timex.compare(new_date, Timex.today()) == -1 do
        %{}
        |> Teiserver.Telemetry.Tasks.PersistServerDayTask.new()
        |> Oban.insert()
      end
    end

    :ok
  end

  @spec run(%Date{}) :: :ok
  def run(date) do
    data = date
      |> get_logs
      |> sum_user_activity

      # Delete old log if it exists
    delete_query =
      from logs in Teiserver.Telemetry.UserActivityDayLog,
        where: logs.date == ^(date |> Timex.to_date())

    Repo.delete_all(delete_query)

    Telemetry.create_user_activity_day_log(%{
      date: date,
      data: data
    })

    :ok
  end

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

  @spec get_logs(Date.t()) :: list()
  defp get_logs(date) do
    start_time = date |> Timex.to_datetime()
    end_time = start_time |> Timex.shift(days: 1)

    Telemetry.list_server_minute_logs(
      search: [
        between: {start_time, end_time}
      ],
      select: [:data]
    )
    |> Enum.map(fn l -> l.data end)
  end

  defp sum_user_activity(logs) do
    start_data = @client_states
      |> Map.new(fn key -> {key, []} end)

    result = logs
    |> Enum.reduce(start_data, fn (log, acc) ->
      %{
        total: log["client"]["total"] ++ acc.total,
        player: log["client"]["player"] ++ acc.player,
        spectator: log["client"]["spectator"] ++ acc.spectator,
        lobby: log["client"]["lobby"] ++ acc.lobby,
        menu: log["client"]["menu"] ++ acc.menu
      }
    end)
    |> Map.new(fn {key, userids} ->
      result = userids
        |> List.flatten
        |> Enum.group_by(fn key ->
          key
        end, fn _ ->
          1
        end)
        |> Map.new(fn {key, ones} ->
          {key, Enum.count(ones)}
        end)

      {key, result}
    end)

    result
  end

  defp add_maps(m1, nil), do: m1

  defp add_maps(m1, m2) do
    Map.merge(m1, m2, fn _k, v1, v2 -> v1 + v2 end)
  end
end
