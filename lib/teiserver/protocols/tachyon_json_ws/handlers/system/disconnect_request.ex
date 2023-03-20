defmodule Teiserver.Tachyon.Handlers.System.DisconnectRequest do
  @moduledoc """

  """

  # @command_id "system/error"

  def execute(%{userid: userid} = conn, _object, _meta) do
    send(self(), :disconnect)
    Teiserver.Client.disconnect(userid, "WS disconnect request")

    response = %{
      "result" => "disconnected"
    }

    {"disconnect", response, conn}
  end
end
