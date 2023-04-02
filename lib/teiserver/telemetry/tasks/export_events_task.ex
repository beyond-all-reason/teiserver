defmodule Teiserver.Telemetry.ExportEventsTask do
  alias Teiserver.Telemetry.{ClientEvent, UnauthEvent}
  alias Central.Helpers.{DatePresets}
  alias Central.Repo
  import Ecto.Query, warn: false
  import Central.Helpers.QueryHelpers

  @spec perform(map) :: map()
  def perform(%{"event_types" => event_types, "timeframe" => timeframe, "auth" => auth}) do
    {start_date, end_date} = DatePresets.parse(timeframe, "", "")

    start_date = Timex.to_datetime(start_date)
    end_date = Timex.to_datetime(end_date)

    case auth do
      "auth" ->
        %{
          "client_events" => query_client(event_types, start_date, end_date)
        }

      "unauth" ->
        %{
          "unauth_events" => query_unauth(event_types, start_date, end_date)
        }

      "combined" ->
        %{
          "client_events" => query_client(event_types, start_date, end_date),
          "unauth_events" => query_unauth(event_types, start_date, end_date)
        }
    end
  end

  def perform(_) do
    %{}
  end

  defp query_client(event_types, start_date, end_date) do
    query =
      from client_events in ClientEvent,
        where: client_events.event_type_id in ^event_types,
        where: between(client_events.timestamp, ^start_date, ^end_date),
        join: event_types in assoc(client_events, :event_type),
        join: users in assoc(client_events, :user),
        select: [users.name, event_types.name, client_events.timestamp, client_events.value]

    stream = Repo.stream(query, max_rows: 500)

    {:ok, result} =
      Repo.transaction(fn ->
        stream
        |> Enum.map(fn [name, event_type, timestamp, value] ->
          %{
            name: name,
            event: event_type,
            timestamp: timestamp,
            value: value
          }
        end)
        |> Enum.to_list()
      end)

    result
  end

  defp query_unauth(event_types, start_date, end_date) do
    query =
      from unauth_events in UnauthEvent,
        where: unauth_events.event_type_id in ^event_types,
        where: between(unauth_events.timestamp, ^start_date, ^end_date),
        join: event_types in assoc(unauth_events, :event_type),
        select: [
          unauth_events.hash,
          event_types.name,
          unauth_events.timestamp,
          unauth_events.value
        ]

    stream = Repo.stream(query, max_rows: 500)

    {:ok, result} =
      Repo.transaction(fn ->
        stream
        |> Enum.map(fn [hash, event_type, timestamp, value] ->
          %{
            hash: hash,
            event: event_type,
            timestamp: timestamp,
            value: value
          }
        end)
        |> Enum.to_list()
      end)

    result
  end
end
