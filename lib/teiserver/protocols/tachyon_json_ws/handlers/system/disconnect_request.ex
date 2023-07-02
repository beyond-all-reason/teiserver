defmodule Teiserver.Tachyon.Handlers.System.DisconnectRequest do
  @moduledoc """

  """

  alias Teiserver.Data.Types, as: T
  alias Teiserver.Tachyon.Responses.System.DisconnectResponse

  # @command_id "system/error"
  @spec dispatch_handlers :: map()
  def dispatch_handlers() do
    %{
      "disconnect" => &execute/3
    }
  end

  @spec execute(T.tachyon_conn(), T.tachyon_object(), map) :: {T.tachyon_response(), T.tachyon_conn()}
  def execute(%{userid: userid} = conn, _object, _meta) do
    send(self(), :disconnect)
    Teiserver.Client.disconnect(userid, "WS disconnect request")

    response = DisconnectResponse.generate("disconnected")

    {response, conn}
  end
end
