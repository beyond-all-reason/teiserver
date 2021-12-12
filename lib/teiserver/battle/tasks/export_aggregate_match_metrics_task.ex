defmodule Teiserver.Battle.ExportAggregateMatchMetricsTask do
  alias Teiserver.Telemetry
  alias Central.Helpers.{DatePresets}

  def perform(params) do
    {start_date, end_date} =
      DatePresets.parse(
        params["date_preset"],
        params["start_date"],
        params["end_date"]
      )

    start_date = Timex.to_datetime(start_date)
    end_date = Timex.to_datetime(end_date)

    Telemetry.list_telemetry_day_logs(
      search: [
        start_date: start_date,
        end_date: end_date
      ],
      limit: :infinity,
      order: "Oldest first"
    )
    |> do_output(params)
  end

  defp do_output(data, _params) do
    data
    |> Stream.map(fn log ->
      log.data
      |> Map.drop(["minutes_per_user"])
      |> Map.put("date", log.date)
    end)
    |> Enum.to_list
    |> Jason.encode!
  end
end
