defmodule Teiserver.Telemetry.GraphMinuteLogsTask do
  @spec perform(list) :: list()
  def perform(logs) do
    [
      ["Users" | Enum.map(logs, fn l -> l.data["client"]["total"] |> Enum.count end)],
      # Enum.map(logs, fn l -> l.data["client"]["player"] |> Enum.count end),

      # Enum.map(logs, fn l -> l.data["battle"]["in_progress"] end),
    ]
  end
end
