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
          :ok | {:missing_schema, command_id(), message_type()} | {:error, map()}
  def parse_message(command_id, type, json) do
    with {:ok, schema} <- get_schema(command_id, type),
         :ok <- JsonXema.validate(schema, json) do
      :ok
    end
  end

  def parse_schema(command_id, type) do
    # basic check to avoid attack where the client could construct an
    # arbitrary path
    if String.contains?(command_id, ".") do
      {:error, "Invalid command id #{command_id}"}
    else
      schema_path = Path.join(["priv", "tachyon", "schema", command_id, "#{type}.json"])
      path = Application.app_dir(:teiserver, schema_path)

      with {:ok, content} <- File.read(path),
           {:ok, json} <- Jason.decode(content) do
        {:ok, json}
      else
        {:error, :enoent} -> {:missing_schema, command_id, type}
        {:error, err} -> {:error, err}
      end
    end
  end

  defp get_schema(command_id, type) do
    Teiserver.cache_get_or_store(@cache_name, {command_id, type}, fn ->
      with {:ok, json} <- parse_schema(command_id, type) do
        {:ok, JsonXema.new(json)}
      end
    end)
  end

  @doc """
  helper to create a tachyon response
  """
  @spec response(command_id(), message_id(), term()) :: map()
  def response(command_id, message_id, data \\ nil) do
    resp = %{
      type: :response,
      status: :success,
      commandId: command_id,
      messageId: message_id
    }

    if is_nil(data) do
      resp
    else
      Map.put(resp, :data, data)
    end
  end

  @spec error_response(command_id(), message_id(), term(), String.t() | nil) :: map()
  def error_response(command_id, message_id, reason, details \\ nil) do
    resp = %{
      type: :response,
      status: :failed,
      commandId: command_id,
      messageId: message_id,
      reason: reason
    }

    if is_nil(details) do
      resp
    else
      Map.put(resp, :details, details)
    end
  end

  @spec event(command_id(), term()) :: map()
  def event(command_id, data \\ nil) do
    ev = %{
      type: :event,
      messageId: UUID.uuid4(),
      commandId: command_id
    }

    if is_nil(data) do
      ev
    else
      Map.put(ev, :data, data)
    end
  end

  @spec request(command_id(), term()) :: %{
          type: :request,
          messageId: message_id(),
          commandId: command_id()
        }
  def request(command_id, data) do
    ev = %{
      type: :request,
      messageId: UUID.uuid4(),
      commandId: command_id
    }

    if is_nil(data) do
      ev
    else
      Map.put(ev, :data, data)
    end
  end
end
