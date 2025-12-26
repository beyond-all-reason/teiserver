defmodule Teiserver.Telemetry.ExportSimpleMatchEventsTask do
  @moduledoc false
  alias Teiserver.Telemetry.SimpleMatchEvent
  alias Teiserver.Helper.{DatePresets}
  alias Teiserver.Repo
  import Ecto.Query, warn: false
  import Teiserver.Helper.QueryHelpers

  @spec perform(map) :: map()
  def perform(%{"event_types" => event_types, "timeframe" => timeframe}) do
    {start_date, end_date} = DatePresets.parse(timeframe, "", "")

    start_date = Timex.to_datetime(start_date)
    end_date = Timex.to_datetime(end_date)

    query_client(event_types, start_date, end_date)
    |> add_csv_headings()
    |> CSV.encode()
    |> Enum.to_list()
  end

  def perform(_) do
    %{}
  end

  defp add_csv_headings(output) do
    headings = [
      [
        "Event",
        "User",
        "Match",
        "Game time"
      ]
    ]

    headings ++ output
  end

  defp query_client(event_types, start_date, end_date) do
    query =
      from match_events in SimpleMatchEvent,
        where: match_events.event_type_id in ^event_types,
        left_join: matches in assoc(match_events, :match),
        where: between(matches.started, ^start_date, ^end_date),
        join: event_types in assoc(match_events, :event_type),
        left_join: users in assoc(match_events, :user),
        select: [users.name, event_types.name, match_events.game_time, match_events.match_id]

    stream = Repo.stream(query, max_rows: 500)

    {:ok, result} =
      Repo.transaction(fn ->
        stream
        |> Enum.map(fn [username, event_type, game_time, match_id] ->
          [
            event_type,
            username,
            match_id,
            game_time
          ]
        end)
        |> Enum.to_list()
      end)

    result
  end
end
