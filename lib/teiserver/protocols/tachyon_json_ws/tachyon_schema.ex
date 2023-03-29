defmodule Teiserver.Tachyon.Schema do
  @moduledoc """

  """

  @spec load_schemas :: list
  def load_schemas() do
    "priv/tachyon/v1.json"
    |> File.read!()
    |> Jason.decode!()
    |> Map.get("properties")
    |> Enum.map(fn {_section_key, section} ->
      section
      |> Map.get("properties")
      |> Enum.map(fn {_cmd_name, cmd} ->
        [
          cmd["properties"]["request"],
          cmd["properties"]["response"]
        ]
      end)
    end)
    |> List.flatten()
    |> Enum.reject(&(&1 == nil))
    |> Enum.map(fn json_def ->
      schema = JsonXema.new(json_def)
      command = get_in(json_def, ~w(properties command const))

      ConCache.put(:tachyon_schemas, command, schema)
      json_def["$id"]
    end)
  end

  @spec validate!(map) :: :ok
  def validate!(%{"command" => command} = object) do
    schema = get_schema(command)
    JsonXema.validate!(schema, object)
  end

  defp get_schema(command) do
    ConCache.get(:tachyon_schemas, command)
  end
end
