defmodule Teiserver.Logging.Tasks.PersistUserActivityDayTask do
  @moduledoc false
  use Oban.Worker, queue: :teiserver
  alias Teiserver.{Logging}

  alias Teiserver.Repo
  import Ecto.Query, warn: false

  @client_states ~w(lobby menu player spectator total)a

  @impl Oban.Worker
  @spec perform(any) :: :ok
  def perform(_) do
    last_date = Logging.get_last_user_activity_day_log()

    date =
      if last_date == nil do
        Logging.get_first_telemetry_minute_datetime()
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
        |> Teiserver.Logging.Tasks.PersistUserActivityDayTask.new()
        |> Oban.insert()
      end
    end

    :ok
  end

  @spec run(Date.t()) :: :ok
  def run(date) do
    data =
      date
      |> get_logs()
      |> sum_user_activity()

    # Delete old log if it exists
    delete_query =
      from logs in Teiserver.Logging.UserActivityDayLog,
        where: logs.date == ^(date |> Timex.to_date())

    Repo.delete_all(delete_query)

    {:ok, _} =
      Logging.create_user_activity_day_log(%{
        date: date,
        data: data
      })

    :ok
  end

  @spec get_logs(Date.t()) :: list()
  defp get_logs(date) do
    start_time = date |> Timex.to_datetime()
    end_time = start_time |> Timex.shift(days: 1)

    Logging.list_server_minute_logs(
      search: [
        between: {start_time, end_time}
      ],
      limit: :infinity,
      select: [:data]
    )
    |> Enum.map(fn l -> l.data end)
  end

  defp sum_user_activity(logs) do
    start_data =
      @client_states
      |> Map.new(fn key -> {key, []} end)

    result =
      logs
      |> Enum.reduce(start_data, fn log, acc ->
        %{
          total: log["client"]["total"] ++ acc.total,
          player: log["client"]["player"] ++ acc.player,
          spectator: log["client"]["spectator"] ++ acc.spectator,
          lobby: log["client"]["lobby"] ++ acc.lobby,
          menu: log["client"]["menu"] ++ acc.menu
        }
      end)
      |> Map.new(fn {key, userids} ->
        result =
          userids
          |> List.flatten()
          |> Enum.group_by(
            fn key ->
              key
            end,
            fn _ ->
              1
            end
          )
          |> Map.new(fn {key, ones} ->
            {key, Enum.count(ones)}
          end)

        {key, result}
      end)

    result
  end
end
