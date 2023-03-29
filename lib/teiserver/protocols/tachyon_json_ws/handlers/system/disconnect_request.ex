defmodule Teiserver.Tachyon.Handlers.System.DisconnectRequest do
  @moduledoc """

  """

  # @command_id "system/error"
  @spec dispatch_handlers :: map()
  def dispatch_handlers() do
    %{
      "disconnect" => &execute/3
    }
  end

  def execute(%{userid: userid} = conn, _object, _meta) do
    send(self(), :disconnect)
    Teiserver.Client.disconnect(userid, "WS disconnect request")

    response = %{
      "result" => "disconnected"
    }

    {"disconnect", response, conn}
  end
end
