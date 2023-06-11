defmodule Teiserver.Tachyon.Handlers.Lobby.UpdateStatusRequest do
  @moduledoc """

  """
  alias Teiserver.Data.Types, as: T
  alias Teiserver.Tachyon.Responses.Lobby.UpdateStatusResponse
  alias Teiserver.{Account}

  @spec dispatch_handlers :: map()
  def dispatch_handlers() do
    %{
      "lobby/updateStatus/request" => &execute/3
    }
  end

  @spec execute(T.tachyon_conn(), map, map) ::
          {{T.tachyon_command(), T.tachyon_object()}, T.tachyon_conn()}
  def execute(conn, status, _meta) do
    IO.puts ""
    IO.inspect status
    IO.puts ""

    response = :ok

    {response, conn}
  end
end
