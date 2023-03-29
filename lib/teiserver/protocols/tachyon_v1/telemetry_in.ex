defmodule Teiserver.Protocols.Tachyon.V1.TelemetryIn do
  alias Teiserver.Telemetry

  @spec do_handle(String.t(), Map.t(), Map.t()) :: Map.t()
  def do_handle(
        "update_property",
        %{"hash" => hash, "property" => property, "value" => value},
        state
      ) do
    Telemetry.log_client_property(state.userid, property, value, hash)
    state
  end

  def do_handle("log_event", %{"event" => event, "value" => value, "hash" => hash}, state) do
    Telemetry.log_client_event(state.userid, event, value, hash)
    state
  end
end
