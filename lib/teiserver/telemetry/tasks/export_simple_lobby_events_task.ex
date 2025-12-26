defmodule Teiserver.Telemetry.ExportSimpleLobbyEventsTask do
  @moduledoc false
  alias Teiserver.Telemetry.SimpleLobbyEvent
  alias Teiserver.Helper.{DatePresets}
  alias Teiserver.Repo
  import Ecto.Query, warn: false
  import Teiserver.Helper.QueryHelpers

  @spec perform(map) :: map()
  def perform(%{"event_types" => event_types, "timeframe" => timeframe}) do
    {start_date, end_date} = DatePresets.parse(timeframe, "", "")

    start_date = Timex.to_datetime(start_date)
    end_date = Timex.to_datetime(end_date)

    query_lobby(event_types, start_date, end_date)
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
        "Lobby",
        "Game time"
      ]
    ]

    headings ++ output
  end

  defp query_lobby(event_types, start_date, end_date) do
    query =
      from lobby_events in SimpleLobbyEvent,
        where: lobby_events.event_type_id in ^event_types,
        where: between(lobby_events.timestamp, ^start_date, ^end_date),
        join: event_types in assoc(lobby_events, :event_type),
        left_join: users in assoc(lobby_events, :user),
        select: [users.name, event_types.name, lobby_events.game_time, lobby_events.lobby_id]

    stream = Repo.stream(query, max_rows: 500)

    {:ok, result} =
      Repo.transaction(fn ->
        stream
        |> Enum.map(fn [username, event_type, game_time, lobby_id] ->
          [
            event_type,
            username,
            lobby_id,
            game_time
          ]
        end)
        |> Enum.to_list()
      end)

    result
  end
end
