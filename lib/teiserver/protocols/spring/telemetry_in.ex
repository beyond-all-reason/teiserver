defmodule Teiserver.Protocols.Spring.TelemetryIn do
  alias Teiserver.Telemetry
  alias Teiserver.Protocols.SpringIn
  # import Teiserver.Protocols.SpringOut, only: [reply: 5]
  # import Central.Helpers.NumberHelper, only: [int_parse: 1]

  @spec do_handle(String.t(), String.t(), String.t() | nil, Map.t()) :: Map.t()
  def do_handle("log_client_event", data, _msg_id, state) do
    case Regex.run(~r/(\S+) (\S+)/, data) do
      [_, event, value] ->
        Telemetry.log_client_event(state.userid, event, value)

      nil ->
        :ok
    end
    state
  end

  def do_handle("update_client_property", data, _msg_id, state) do
    case Regex.run(~r/(\S+) (\S+)/, data) do
      [_, event, value] ->
        Telemetry.update_client_property(state.userid, event, value)

      nil ->
        :ok
    end
    state
  end

  def do_handle("log_battle_event", data, _msg_id, state) do
    case Regex.run(~r/(\S+) (\S+)/, data) do
      [_, event, value] ->
        Telemetry.log_battle_event(state.userid, event, value)

      nil ->
        :ok
    end
    state
  end

  def do_handle(cmd, data, msg_id, state) do
    SpringIn._no_match(state, "c.telemetry." <> cmd, msg_id, data)
  end
end
