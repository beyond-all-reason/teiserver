defmodule Barserver.Tachyon.Handlers.Telemetry.EventRequest do
  @moduledoc """

  """
  alias Barserver.Data.Types, as: T
  alias Barserver.Tachyon.Responses.Telemetry.EventResponse
  alias Barserver.{Telemetry}

  @spec dispatch_handlers :: map()
  def dispatch_handlers() do
    %{
      "telemetry/event/request" => &execute/3
    }
  end

  @spec execute(T.tachyon_conn(), T.tachyon_object(), map) ::
          {T.tachyon_response(), T.tachyon_conn()}
  def execute(conn, %{"type" => event_type, "value" => value}, _meta) do
    Telemetry.log_complex_client_event(conn.userid, event_type, value)

    response = EventResponse.generate(:ok)

    {response, conn}
  end
end
