defmodule Teiserver.Telemetry.ServerGraphDayLogsTask do
  @spec perform(list, map(), function()) :: list()
  def perform(logs, %{"field_list" => field_list} = _params, mapper_function) do
    field_list
    |> Enum.map(fn
      {name, path, getter} ->
        [name | build_line(logs, path, mapper_function, getter)]

      {name, path} ->
        [name | build_line(logs, path, mapper_function)]

      field_name ->
        name =
          String.split(field_name, ".")
          |> Enum.reverse()
          |> hd

        [name | build_line(logs, field_name, mapper_function)]
    end)
  end

  @spec build_line(list, String.t(), function()) :: list()
  defp build_line(logs, field_name, mapper_function, getter \\ nil) do
    getter = getter || String.split(field_name, ".")

    logs
    |> Enum.map(fn log ->
      get_in(log.data, getter)
    end)
    |> List.flatten()
    |> Enum.map(mapper_function)
  end
end
