defmodule Teiserver.Telemetry.ExportServerMetricsTask do
  alias Teiserver.Telemetry
  # alias Central.Helpers.{TimexHelper, DatePresets}

  def perform(params) do
    Telemetry.list_telemetry_day_logs(
      search: [],
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
