defmodule Teiserver.Telemetry.ExportEventsTask do
  alias Teiserver.Telemetry
  alias Central.Helpers.{TimexHelper, DatePresets}

  def perform(params) do
    do_query(params)
    |> do_output(params)
  end

  defp do_query(%{"event_type" => event_type, "timeframe" => timeframe, "auth" => auth}) do
    {start_date, end_date} = DatePresets.parse(timeframe, "", "")

    start_date = Timex.to_datetime(start_date)
    end_date = Timex.to_datetime(end_date)

    case auth do
      "auth" ->
        query_auth(event_type, start_date, end_date)
      "unauth" ->
        query_unauth(event_type, start_date, end_date)
      "combined" ->
        query_auth(event_type, start_date, end_date) ++ query_unauth(event_type, start_date, end_date)
    end
  end

  defp query_auth(event_type, start_date, end_date) do
    Telemetry.list_client_events(
      preload: [:event_type, :user],
      search: [
        between: {start_date, end_date},
        event_type_id: event_type
      ],
      limit: :infinity
    )
  end

  defp query_unauth(event_type, start_date, end_date) do
    Telemetry.list_unauth_events(
      preload: [:event_type],
      search: [
        between: {start_date, end_date},
        event_type_id: event_type
      ],
      limit: :infinity
    )
  end

  defp do_output(data, _params) do
    data
    |> Stream.map(fn event ->
      {username, hash} = if Map.has_key?(event, :user) do
        {event.user.name, nil}
      else
        {nil, event.hash}
      end

      %{
        user: username,
        hash: hash,
        event_type: event.event_type.name,
        timestamp: TimexHelper.date_to_str(event.timestamp, format: :ymd_hms),
        value: event.value
      }
    end)
    |> Enum.to_list
    |> Jason.encode!
  end
end
