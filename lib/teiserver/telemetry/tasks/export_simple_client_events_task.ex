defmodule Teiserver.Telemetry.ExportSimpleClientEventsTask do
  @moduledoc false
  alias Teiserver.Telemetry.SimpleClientEvent
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
        "Client",
        "Game time"
      ]
    ]

    headings ++ output
  end

  defp query_client(event_types, start_date, end_date) do
    query =
      from client_events in SimpleClientEvent,
        where: client_events.event_type_id in ^event_types,
        where: between(client_events.timestamp, ^start_date, ^end_date),
        join: event_types in assoc(client_events, :event_type),
        left_join: users in assoc(client_events, :user),
        select: [users.name, event_types.name, client_events.game_time, client_events.client_id]

    stream = Repo.stream(query, max_rows: 500)

    {:ok, result} =
      Repo.transaction(fn ->
        stream
        |> Enum.map(fn [username, event_type, game_time, client_id] ->
          [
            event_type,
            username,
            client_id,
            game_time
          ]
        end)
        |> Enum.to_list()
      end)

    result
  end
end
