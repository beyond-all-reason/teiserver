defmodule Teiserver.Telemetry.ExportPropertiesTask do
  alias Teiserver.Telemetry
  alias Central.Helpers.{TimexHelper, DatePresets}

  def perform(params) do
    do_query(params)
    |> do_output(params)
    |> add_csv_headings
  end

  defp add_csv_headings(output) do
    headings = [[
      "Username",
      "Hash",
      "Property",
      "Last updated",
      "Value"
    ]]
    |> CSV.encode()
    |> Enum.to_list

    headings ++ output
  end

  defp do_query(%{"property_type" => property_type, "timeframe" => timeframe, "auth" => auth}) do
    {start_date, end_date} = DatePresets.parse(timeframe, "", "")

    start_date = Timex.to_datetime(start_date)
    end_date = Timex.to_datetime(end_date)

    case auth do
      "auth" ->
        query_auth(property_type, start_date, end_date)
      "unauth" ->
        query_unauth(property_type, start_date, end_date)
      "combined" ->
        query_auth(property_type, start_date, end_date) ++ query_unauth(property_type, start_date, end_date)
    end
  end

  defp query_auth(property_type, start_date, end_date) do
    Telemetry.list_client_properties(
      preload: [:property_type, :user],
      search: [
        between: {start_date, end_date},
        property_type_id: property_type
      ],
      limit: :infinity
    )
  end

  defp query_unauth(property_type, start_date, end_date) do
    Telemetry.list_unauth_properties(
      preload: [:property_type],
      search: [
        between: {start_date, end_date},
        property_type_id: property_type
      ],
      limit: :infinity
    )
  end

  defp do_output(data, _params) do
    data
    |> Stream.map(fn property ->
      {username, hash} = if Map.has_key?(property, :user) do
        {property.user.name, nil}
      else
        {nil, property.hash}
      end

      [
        username,
        hash,
        property.property_type.name,
        TimexHelper.date_to_str(property.last_updated, format: :ymd_hms),
        property.value
      ]
    end)
    |> CSV.encode()
    |> Enum.to_list
  end
end
