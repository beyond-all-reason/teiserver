defmodule Teiserver.Protocols.Spring.TelemetryIn do
  alias Teiserver.Telemetry
  alias Teiserver.Protocols.SpringIn
  # import Teiserver.Protocols.SpringOut, only: [reply: 5]
  # import Central.Helpers.NumberHelper, only: [int_parse: 1]

  @spec do_handle(String.t(), String.t(), String.t() | nil, Map.t()) :: Map.t()
  def do_handle("update_client_property", data, _msg_id, state) do
    case Regex.run(~r/(\S+) (\S+) (\S+)/, data) do
      [_, event, json_value, json_hash] ->
        value = Base.decode64(json_value)
        hash = Base.decode64(json_hash)

        if value != :error and hash != :error do
          {:ok, value} = value
          {:ok, hash} = hash

          Telemetry.log_client_property(state.userid, event, value, hash)
        end
      nil ->
        :ok
    end
    state
  end

  def do_handle("log_client_event", data, _msg_id, state) do
    case Regex.run(~r/(\S+) (\S+) (\S+)/, data) do
      [_, event, json_value, json_hash] ->
        value = decode_value(json_value)
        hash = Base.decode64(json_hash)

        if value != :error and hash != :error do
          {:ok, value} = value
          {:ok, hash} = hash

          Telemetry.log_client_event(state.userid, event, value, hash)
        end
      nil ->
        :ok
    end
    state
  end

  def do_handle("log_battle_event", data, _msg_id, state) do
    case Regex.run(~r/(\S+) (\S+) (\S+)/, data) do
      [_, event, json_value, json_hash] ->
        value = decode_value(json_value)
        hash = Base.decode64(json_hash)

        if value != :error and hash != :error do
          {:ok, value} = value
          {:ok, hash} = hash

          Telemetry.log_battle_event(state.userid, event, value, hash)
        end
      nil ->
        :ok
    end
    state
  end

  def do_handle(cmd, data, msg_id, state) do
    SpringIn._no_match(state, "c.telemetry." <> cmd, msg_id, data)
  end

  defp decode_value(raw) do
    case Base.decode64(raw) do
      {:ok, string} ->
        case Jason.decode(string) do
          {:ok, json} ->
            {:ok, json}
          _ ->
            :error
        end

      _ ->
        :error
    end
  end
end
