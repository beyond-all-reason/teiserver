defmodule Teiserver.Logging.ServerGraphDayLogsTask do
  @spec perform(list, map(), function()) :: list()
  def perform(logs, %{"field_list" => field_list} = _params, mapper_function) do
    field_list
    |> Enum.map(fn
      {name, path, getter} ->
        [name | build_line(logs, path, mapper_function, getter)]

      {name, path} ->
        [name | build_line(logs, path, mapper_function, nil)]

      field_name ->
        name =
          String.split(field_name, ".")
          |> Enum.reverse()
          |> hd

        [name | build_line(logs, field_name, mapper_function, nil)]
    end)
  end

  @spec build_line(list, [String.t()], function(), nil | function()) :: list()
  defp build_line(logs, fields, mapper_function, getter) when is_list(fields) do
    fields
      |> Enum.map(fn f ->
        do_build_line(logs, f, mapper_function, getter)
      end)
      |> Enum.zip
      |> Enum.map(fn values ->
        values
          |> Tuple.to_list()
          |> Enum.sum
      end)
  end

  defp build_line(logs, field_name, mapper_function, getter), do: build_line(logs, [field_name], mapper_function, getter)

  defp do_build_line(logs, field_name, mapper_function, getter) do
    getter = getter || String.split(field_name, ".")

    logs
    |> Enum.map(fn log ->
      get_in(log.data, getter)
    end)
    |> List.flatten()
    |> Enum.map(mapper_function)
  end
end
