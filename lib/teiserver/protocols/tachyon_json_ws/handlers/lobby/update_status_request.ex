defmodule Teiserver.Tachyon.Handlers.Lobby.UpdateStatusRequest do
  @moduledoc """

  """
  alias Teiserver.Data.Types, as: T
  # alias Teiserver.Tachyon.Responses.Lobby.UpdateStatusResponse
  # alias Teiserver.{Account}

  @spec dispatch_handlers :: map()
  def dispatch_handlers() do
    %{
      "lobby/updateStatus/request" => &execute/3
    }
  end

  @spec execute(T.tachyon_conn(), T.tachyon_object(), map) :: {T.tachyon_response(), T.tachyon_conn()}
  def execute(conn, status, _meta) do
    IO.puts ""
    IO.inspect status
    IO.puts ""

    raise "Not implemented"
    response = {"lobby/updateStatus/response", :success, %{}}

    {response, conn}
  end
end
