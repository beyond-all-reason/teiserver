defmodule Teiserver.Telemetry.Tasks.PersistMatchDayTask do
  use Oban.Worker, queue: :teiserver
  alias Teiserver.{Telemetry, Battle}
  alias Teiserver.Battle.Tasks.BreakdownMatchDataTask

  alias Central.Repo
  import Ecto.Query, warn: false

  @impl Oban.Worker
  @spec perform(any) :: :ok
  def perform(_) do
    last_date = Telemetry.get_last_match_day_log()

    date =
      if last_date == nil do
        case Battle.list_matches(limit: 1, order_by: "Oldest first") do
          [] ->
            nil

          [match] ->
            Timex.to_date(match.inserted_at)
        end
      else
        last_date
        |> Timex.shift(days: 1)
      end

    cond do
      date == nil ->
        :ok

      Timex.compare(date, Timex.today()) == -1 ->
        run(date)

        new_date = Timex.shift(date, days: 1)

        if Timex.compare(new_date, Timex.today()) == -1 do
          %{}
          |> Teiserver.Telemetry.Tasks.PersistMatchDayTask.new()
          |> Oban.insert()
        end

        :ok

      true ->
        :ok
    end
  end

  # To re-run yesterday's data
  # Teiserver.Telemetry.Tasks.PersistMatchDayTask.run(Timex.today |> Timex.shift(days: -1))

  @spec run(%Date{}) :: :ok
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
      from logs in Teiserver.Telemetry.MatchDayLog,
        where: logs.date == ^(date |> Timex.to_date())

    Repo.delete_all(delete_query)

    Telemetry.create_match_day_log(%{
      date: date,
      data: data
    })

    :ok
  end
end
