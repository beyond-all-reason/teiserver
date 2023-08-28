defmodule Teiserver.Tachyon.Handlers.System.PingRequest do
  @moduledoc """

  """
  alias Teiserver.Data.Types, as: T
  alias Teiserver.Tachyon.Responses.System.PingResponse

  @spec dispatch_handlers :: map()
  def dispatch_handlers() do
    %{
      "system/ping/request" => &execute/3
    }
  end

  @spec execute(T.tachyon_conn(), T.tachyon_object(), map) ::
          {T.tachyon_response(), T.tachyon_conn()}
  def execute(conn, _object, _meta) do
    response = PingResponse.generate(conn)

    {response, conn}
  end
end
