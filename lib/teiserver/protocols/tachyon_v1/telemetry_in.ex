defmodule Teiserver.Protocols.Tachyon.V1.TelemetryIn do
  alias Teiserver.Telemetry

  @spec do_handle(String.t(), Map.t(), Map.t()) :: Map.t()
  def do_handle(
        "update_property",
        %{"property" => property, "value" => value},
        state
      ) do
    Telemetry.log_user_property(state.userid, property, value)
    state
  end

  def do_handle("log_event", %{"event" => event, "value" => value}, state) do
    Telemetry.log_complex_client_event(state.userid, event, value)
    state
  end
end
