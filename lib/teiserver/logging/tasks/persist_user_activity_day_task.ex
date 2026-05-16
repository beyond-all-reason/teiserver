defmodule Teiserver.Logging.Tasks.PersistUserActivityDayTask do
  @moduledoc false

  alias Teiserver.Helper.DateHelper
  alias Teiserver.Logging
  alias Teiserver.Logging.Tasks.PersistUserActivityDayTask
  alias Teiserver.Repo

  use Oban.Worker, queue: :teiserver

  import Ecto.Query, warn: false

  @client_states ~w(lobby menu player spectator total)a

  @impl Oban.Worker
  @spec perform(any) :: :ok
  def perform(_job) do
    last_date = Logging.get_last_user_activity_day_log()

    date =
      if last_date == nil do
        Logging.get_first_telemetry_minute_datetime()
        |> DateTime.to_date()
      else
        last_date
        |> Date.add(1)
      end

    if Date.compare(date, Date.utc_today()) == :lt do
      run(date)

      new_date = Date.add(date, 1)

      if Date.compare(new_date, Date.utc_today()) == :lt do
        %{}
        |> PersistUserActivityDayTask.new()
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
        where: logs.date == ^date

    Repo.delete_all(delete_query)

    {:ok, _log} =
      Logging.create_user_activity_day_log(%{
        date: date,
        data: data
      })

    :ok
  end

  @spec get_logs(Date.t()) :: list()
  defp get_logs(date) do
    start_time = DateHelper.to_datetime(date)
    end_time = DateTime.add(start_time, 1, :day)

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
          fn _value ->
            1
          end
        )
        |> Map.new(fn {key, ones} ->
          {key, Enum.count(ones)}
        end)

      {key, result}
    end)
  end
end
