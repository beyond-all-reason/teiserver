defmodule Teiserver.Logging.Tasks.PersistMatchDayTask do
  @moduledoc false
  alias Teiserver.Battle
  alias Teiserver.Battle.Tasks.BreakdownMatchDataTask
  alias Teiserver.Logging
  alias Teiserver.Logging.MatchDayLog
  alias Teiserver.Repo
  use Oban.Worker, queue: :teiserver
  import Ecto.Query, warn: false

  @impl Oban.Worker
  @spec perform(any) :: :ok
  def perform(_job) do
    last_date = Logging.get_last_match_day_log()

    date =
      if last_date == nil do
        case Battle.list_matches(limit: 1, order_by: "Oldest first") do
          [] ->
            nil

          [match] ->
            NaiveDateTime.to_date(match.inserted_at)
        end
      else
        last_date
        |> Date.add(1)
      end

    cond do
      date == nil ->
        :ok

      Date.compare(date, Date.utc_today()) == :lt ->
        run(date)

        new_date = Date.add(date, 1)

        if Date.compare(new_date, Date.utc_today()) == :lt do
          %{}
          |> __MODULE__.new()
          |> Oban.insert()
        end

        :ok

      true ->
        :ok
    end
  end

  # To re-run yesterday's data
  # Teiserver.Logging.Tasks.PersistMatchDayTask.run(Date.add(Date.utc_today(), -1))

  @spec run(Date.t()) :: :ok
  def run(date) do
    data = BreakdownMatchDataTask.perform(date)

    # Check some numbers add up....
    # combined_count = ~w(duel team ffa team_ffa scavengers raptors bots)a
    #   |> Enum.reduce({0, 0}, fn (key, {tc, wc}) ->
    #     tc = tc + get_in(data, [key, :aggregate, :total_count])
    #     wc = wc + get_in(data, [key, :aggregate, :weighted_count])

    #     {tc, wc}
    #   end)

    # IO.puts ""
    # IO.inspect {data.totals.aggregate.total_count, data.totals.aggregate.weighted_count}
    # IO.inspect combined_count
    # IO.puts ""

    # Delete old log if it exists
    delete_query =
      from logs in MatchDayLog,
        where: logs.date == ^date

    Repo.delete_all(delete_query)

    Logging.create_match_day_log(%{
      date: date,
      data: data
    })

    :ok
  end
end
