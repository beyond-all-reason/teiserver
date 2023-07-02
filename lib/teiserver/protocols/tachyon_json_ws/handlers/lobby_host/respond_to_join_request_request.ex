defmodule Teiserver.Tachyon.Handlers.LobbyHost.RespondToJoinRequestRequest do
  @moduledoc """

  """
  alias Teiserver.Data.Types, as: T
  alias Teiserver.Lobby
  alias Teiserver.Tachyon.Responses.LobbyHost.RespondToJoinRequestResponse

  @spec dispatch_handlers :: map()
  def dispatch_handlers() do
    %{
      "lobbyHost/respondToJoinRequest/request" => &execute/3
    }
  end

  @spec execute(T.tachyon_conn(), map, map) ::
          {{T.tachyon_command(), T.tachyon_object()}, T.tachyon_conn()}
  def execute(conn, %{"response" => "accept"} = object, _meta) do
    Lobby.accept_join_request(object["userid"], conn.lobby_id)

    response = RespondToJoinRequestResponse.generate(:ok)
    {response, conn}
  end

  def execute(conn, %{"response" => "deny", "reason" => reason} = object, _meta) do
    Lobby.deny_join_request(object["userid"], conn.lobby_id, reason)

    response = RespondToJoinRequestResponse.generate(:ok)
    {response, conn}
  end
end
