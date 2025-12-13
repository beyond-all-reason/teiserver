defmodule Teiserver.Telemetry.ExportPropertiesTask do
  @moduledoc false
  alias Teiserver.Helper.{TimexHelper, DatePresets}
  alias Teiserver.Telemetry.{UserProperty, AnonProperty}
  alias Teiserver.Repo
  import Ecto.Query, warn: false
  import Teiserver.Helper.QueryHelpers

  def perform(params) do
    do_query(params)
    |> add_csv_headings()
    |> CSV.encode()
    |> Enum.to_list()
  end

  defp add_csv_headings(output) do
    headings = [
      [
        "Name",
        "Property",
        "Last updated",
        "Value"
      ]
    ]

    headings ++ output
  end

  defp do_query(%{"property_types" => property_types, "timeframe" => timeframe, "auth" => auth}) do
    {start_date, end_date} = DatePresets.parse(timeframe, "", "")

    start_date = Timex.to_datetime(start_date)
    end_date = Timex.to_datetime(end_date)

    case auth do
      "auth" ->
        query_client(property_types, start_date, end_date)

      "unauth" ->
        query_unauth(property_types, start_date, end_date)

      "combined" ->
        query_client(property_types, start_date, end_date) ++
          query_unauth(property_types, start_date, end_date)
    end
  end

  defp query_client(property_types, start_date, end_date) do
    query =
      from client_properties in UserProperty,
        where: client_properties.property_type_id in ^property_types,
        where: between(client_properties.last_updated, ^start_date, ^end_date),
        join: property_types in assoc(client_properties, :property_type),
        join: users in assoc(client_properties, :user),
        select: [
          users.name,
          property_types.name,
          client_properties.last_updated,
          client_properties.value
        ]

    stream = Repo.stream(query, max_rows: 500)

    {:ok, result} =
      Repo.transaction(fn ->
        stream
        |> Enum.map(fn [name, property_type, last_updated, value] ->
          [
            name,
            property_type,
            TimexHelper.date_to_str(last_updated, format: :ymd_hms),
            value
          ]
        end)
        |> Enum.to_list()
      end)

    result
  end

  defp query_unauth(property_types, start_date, end_date) do
    query =
      from unauth_properties in AnonProperty,
        where: unauth_properties.property_type_id in ^property_types,
        where: between(unauth_properties.last_updated, ^start_date, ^end_date),
        join: property_types in assoc(unauth_properties, :property_type),
        select: [
          unauth_properties.hash,
          property_types.name,
          unauth_properties.last_updated,
          unauth_properties.value
        ]

    stream = Repo.stream(query, max_rows: 500)

    {:ok, result} =
      Repo.transaction(fn ->
        stream
        |> Enum.map(fn [hash, property_type, last_updated, value] ->
          [
            hash,
            property_type,
            TimexHelper.date_to_str(last_updated, format: :ymd_hms),
            value
          ]
        end)
        |> Enum.to_list()
      end)

    result
  end
end
