defmodule Teiserver.Protocols.Spring.TelemetryIn do
  alias Teiserver.Telemetry
  alias Teiserver.Protocols.SpringIn
  # import Teiserver.Protocols.SpringOut, only: [reply: 5]
  # import Central.Helpers.NumberHelper, only: [int_parse: 1]

  @spec do_handle(String.t(), String.t(), String.t() | nil, Map.t()) :: Map.t()
  def do_handle("log_client_event", data, _msg_id, state) do
    # Do Base64 -> Gzip -> JSON decode?
    Telemetry.log_client_event(data)
    state
  end

  def do_handle("log_battle_event", data, _msg_id, state) do
    # Do Base64 -> Gzip -> JSON decode?
    Telemetry.log_battle_event(data)
    state
  end

  def do_handle(cmd, data, msg_id, state) do
    SpringIn._no_match(state, "c.telemetry." <> cmd, msg_id, data)
  end
end
