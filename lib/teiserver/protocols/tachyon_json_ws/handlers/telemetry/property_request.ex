defmodule Barserver.Tachyon.Handlers.Telemetry.PropertyRequest do
  @moduledoc """

  """
  alias Barserver.Data.Types, as: T
  alias Barserver.Tachyon.Responses.Telemetry.PropertyResponse
  alias Barserver.{Telemetry}

  @spec dispatch_handlers :: map()
  def dispatch_handlers() do
    %{
      "telemetry/property/request" => &execute/3
    }
  end

  @spec execute(T.tachyon_conn(), T.tachyon_object(), map) ::
          {T.tachyon_response(), T.tachyon_conn()}
  def execute(conn, %{"type" => property_type, "value" => value}, _meta) do
    Telemetry.log_user_property(conn.userid, property_type, value)

    response = PropertyResponse.generate(:ok)

    {response, conn}
  end
end
