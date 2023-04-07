defmodule Teiserver.Tachyon.Handlers.Lobby.LeaveRequest do
  @moduledoc """

  """
  alias Teiserver.Data.Types, as: T

  @spec dispatch_handlers :: map()
  def dispatch_handlers() do
    %{
      "lobby/leave/request" => &execute/3
    }
  end

  @spec execute(T.tachyon_conn(), map, map) ::
          {{T.tachyon_command(), T.tachyon_object()}, T.tachyon_conn()}
  def execute(conn, _object, _meta) do
    response = %{}

    {"lobby/leave/request", response, conn}
  end
end
