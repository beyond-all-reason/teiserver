defmodule Teiserver.Tachyon.Schema do
  @moduledoc """
  utilities to parse tachyon schemas
  """
  require Logger

  @type command_id :: String.t()
  @type message_id :: String.t()
  @type message_type :: String.t()

  @cache_name :tachyon_schema_cache

  def cache_spec() do
    Teiserver.Helpers.CacheHelper.concache_perm_sup(@cache_name)
  end

  @doc """
  ensure the given argument represent a valid tachyon enveloppe (type, message id, command id)
  """
  @spec parse_envelope(any()) ::
          {:ok, command_id(), message_type(), message_id()} | {:error, term()}
  def parse_envelope(raw_json) do
    schema =
      Teiserver.cache_get_or_store(@cache_name, :envelope, fn ->
        """
        {
          "title": "tachyon envelope",
          "type": "object",
          "properties": {
            "type": {"type": "string"},
            "messageId": {"type": "string"},
            "commandId": {"type": "string"},
            "data": {"type": "object"}
          },
          "required": ["type", "messageId", "commandId"]
        }
        """
        |> Jason.decode!()
        |> JsonXema.new()
      end)

    case JsonXema.validate(schema, raw_json) do
      :ok ->
        {:ok, Map.get(raw_json, "commandId"), Map.get(raw_json, "type"),
         Map.get(raw_json, "messageId")}

      {:error, err} ->
        {:error, "Invalid tachyon message: #{inspect(err)}"}
    end
  end

  @spec parse_message(command_id(), message_type(), term()) ::
          :ok | :missing_schema | {:error, map()}
  def parse_message(command_id, type, json) do
    with {:ok, schema} <- get_schema(command_id, type),
         :ok <- JsonXema.validate(schema, json) do
      :ok
    end
  end

  defp get_schema(command_id, type) do
    # improvement: cache this operation
    # basic check to avoid attack where the client could construct an
    # arbitrary path
    if String.contains?(command_id, ".") do
      {:error, "Invalid command id #{command_id}"}
    else
      path = "priv/tachyon/schema/#{command_id}/#{type}.json"

      with {:ok, content} <- File.read(path),
           {:ok, json} <- Jason.decode(content) do
        {:ok, JsonXema.new(json)}
      else
        {:error, :enoent} -> :missing_schema
        {:error, err} -> {:error, err}
      end
    end
  end
end
