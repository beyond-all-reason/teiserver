defmodule Teiserver.Tachyon.Handlers.Communication.SendDirectMessageRequest do
  @moduledoc """

  """
  alias Teiserver.Data.Types, as: T
  alias Teiserver.Tachyon.Responses.Communication.SendDirectMessageResponse
  alias Teiserver.{User}

  @spec dispatch_handlers :: map()
  def dispatch_handlers() do
    %{
      "communication/sendDirectMessage/request" => &execute/3
    }
  end

  @spec execute(T.tachyon_conn(), map, map) ::
          {{T.tachyon_command(), T.tachyon_object()}, T.tachyon_conn()}
  def execute(conn, object, _meta) do
    result = User.send_direct_message(conn.userid, object["to"], object["message"])

    response = SendDirectMessageResponse.generate(result)

    {response, conn}
  end
end
