defmodule Teiserver.Telemetry.ExportServerMetricsTask do
  alias Teiserver.Telemetry
  alias Central.Helpers.{DatePresets, TimexHelper}

  def perform(params) do
    {start_date, end_date} =
      DatePresets.parse(
        params["date_preset"],
        params["start_date"],
        params["end_date"]
      )

    start_date = Timex.to_datetime(start_date)
    end_date = Timex.to_datetime(end_date)

    Telemetry.list_server_day_logs(
      search: [
        start_date: start_date,
        end_date: end_date
      ],
      limit: :infinity,
      order: "Oldest first"
    )
    |> do_output(params)
  end

  defp do_output(data, %{"format" => "json"} = _params) do
    data
    |> Stream.map(fn log ->
      log.data
      |> Map.drop(["minutes_per_user"])
      |> Map.put("date", log.date)
    end)
    |> Enum.to_list()
    |> Jason.encode!()
  end

  defp do_output(data, %{"format" => "csv"} = _params) do
    data
    |> Stream.map(fn log ->
      [
        log.date |> TimexHelper.date_to_str(format: :ymd),
        get_in(log.data, ~w(aggregates stats unique_users)),
        get_in(log.data, ~w(aggregates stats unique_players)),
        get_in(log.data, ~w(aggregates stats peak_user_counts total)),
        get_in(log.data, ~w(aggregates stats peak_user_counts player)),
        get_in(log.data, ~w(aggregates minutes player)),
        get_in(log.data, ~w(aggregates minutes total)),
        get_in(log.data, ~w(aggregates stats accounts_created)),
      ]
    end)
    |> Enum.to_list()
    |> add_csv_headings
    |> CSV.encode()
    |> Enum.to_list()
  end

  defp add_csv_headings(output) do
    headings = [
      [
        "Date",
        "Unique users",
        "Unique players",
        "Peak users",
        "Peak players",
        "Play time",
        "Total time",
        "Registrations"
      ]
    ]

    headings ++ output
  end
end
