defmodule Teiserver.Telemetry.ExportClientAuthEventsTask do
  alias Teiserver.Telemetry
  alias Central.Helpers.{TimexHelper, DatePresets}

  def csv_headings do
    [[
      "Event",
      "Timestamp",
      "Value",
      "Userid"
    ]]
    |> CSV.encode()
    |> Enum.to_list
  end

  # Example params
  # %{
  #   "auth" => "auth",
  #   "event_type" => "1",
  #   "output-format" => "graph",
  #   "property_type" => "1",
  #   "table_name" => "events",
  #   "timeframe" => "This week"
  # }

  def perform(params) do
    do_query(params)
    |> do_output(params)
  end

  defp do_query(%{"event_type" => event_type, "timeframe" => timeframe}) do
    {start_date, end_date} = DatePresets.parse(timeframe, "", "")

    start_date = Timex.to_datetime(start_date)
    end_date = Timex.to_datetime(end_date)

    Telemetry.list_client_events(
      preload: [:event_type, :user],
      search: [
        between: {start_date, end_date},
        event_type_id: event_type
      ],
      limit: :infinity
    )
  end

  defp do_output(data, %{"output-format" => "csv"}) do
    data
    |> Stream.map(fn p ->
      [
        p.user.name,
        p.event_type.name,
        TimexHelper.date_to_str(p.timestamp, format: :ymd_hms),
        Jason.encode!(p.value)
      ]
    end)
    |> CSV.encode()
    |> Enum.to_list
  end
end
