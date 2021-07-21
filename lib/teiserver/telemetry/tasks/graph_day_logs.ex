defmodule Teiserver.Telemetry.GraphDayLogsTask do
  def perform(logs, %{"field_list" => field_list} = _params) do
    field_list
    |> Enum.map(fn field_name ->
      name = String.split(field_name, ".")
      |> Enum.reverse()
      |> hd

      [name | build_line(logs, field_name)]
    end)
  end

  defp build_line(logs, field_name) do
    getter = String.split(field_name, ".")

    logs
    |> Enum.map(fn log ->
      get_in(log.data, getter)
    end)
    |> List.flatten
  end
end
