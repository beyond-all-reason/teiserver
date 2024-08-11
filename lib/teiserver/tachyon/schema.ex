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
  @spec parse_envelope(any()) :: {:ok, message_type(), message_id(), command_id()} | {:error, term()}
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
        {:ok, Map.get(raw_json, "type"), Map.get(raw_json, "messageId"),
         Map.get(raw_json, "commandId")}

      {:error, err} ->
        {:error, "Invalid tachyon message: #{inspect(err)}"}
    end
  end
end
