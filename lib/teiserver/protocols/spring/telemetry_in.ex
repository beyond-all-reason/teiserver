defmodule Teiserver.Protocols.Spring.TelemetryIn do
  alias Teiserver.Telemetry
  alias Teiserver.Protocols.SpringIn
  require Logger
  # import Teiserver.Protocols.SpringOut, only: [reply: 5]
  # import Central.Helpers.NumberHelper, only: [int_parse: 1]

  @spec do_handle(String.t(), String.t(), String.t() | nil, Map.t()) :: Map.t()
  def do_handle("update_client_property", data, _msg_id, state) do
    case Regex.run(~r/(\S+) (\S+) (\S+)/, data) do
      [_, event, value64, hash] ->
        value = Base.decode64(value64)

        if value != :error do
          {:ok, value} = value

          Telemetry.log_client_property(state.userid, event, value, hash)
        else
          Logger.error("update_client_property:bad base64 value - #{data}")
        end
      nil ->
        Logger.error("update_client_property:no match - #{data}")
        :ok
    end
    state
  end

  def do_handle("log_client_event", data, _msg_id, state) do
    case Regex.run(~r/(\S+) (\S+) (\S+)/, data) do
      [_, event, value64, hash] ->
        value =

        case decode_value(value64) do
          {:ok, value} ->
            Telemetry.log_client_event(state.userid, event, value, hash)
          {:error, reason} ->
            Logger.error("log_client_event:#{reason} - #{data}")
        end
      nil ->
        Logger.error("log_client_event:no match - #{data}")
        :ok
    end
    state
  end

  def do_handle(cmd, data, msg_id, state) do
    SpringIn._no_match(state, "c.telemetry." <> cmd, msg_id, data)
  end

  @spec decode_value(String.t()) :: {:ok, any} | {:error, String.t()}
  defp decode_value(raw) do
    case Base.decode64(raw) do
      {:ok, string} ->
        case Jason.decode(string) do
          {:ok, json} ->
            {:ok, json}
          {:error, %Jason.DecodeError{position: position, data: _data}} ->
            {:error, "Json decode error at position #{position}"}
        end

      _ ->
        {:error, "Base64 decode error"}
    end
  end
end
