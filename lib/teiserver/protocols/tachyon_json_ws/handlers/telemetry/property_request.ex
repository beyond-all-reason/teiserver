defmodule Teiserver.Tachyon.Handlers.Telemetry.PropertyRequest do
  @moduledoc """

  """
  alias Teiserver.Data.Types, as: T
  alias Teiserver.Tachyon.Responses.Telemetry.PropertyResponse
  alias Teiserver.{Telemetry}

  @spec dispatch_handlers :: map()
  def dispatch_handlers() do
    %{
      "telemetry/property/request" => &execute/3
    }
  end

  @spec execute(T.tachyon_conn(), T.tachyon_object(), map) :: {T.tachyon_response(), T.tachyon_conn()}
  def execute(conn, %{"type" => property_type, "value" => value, "hash" => hash}, _meta) do
    Telemetry.log_client_property(conn.userid, property_type, value, hash)

    response = PropertyResponse.generate(:ok)

    {response, conn}
  end
end
