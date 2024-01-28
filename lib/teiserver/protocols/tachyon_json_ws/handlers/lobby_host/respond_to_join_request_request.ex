defmodule Barserver.Tachyon.Handlers.LobbyHost.RespondToJoinRequestRequest do
  @moduledoc false
  alias Barserver.Data.Types, as: T
  alias Barserver.Lobby
  alias Barserver.Tachyon.Responses.LobbyHost.RespondToJoinRequestResponse

  @spec dispatch_handlers :: map()
  def dispatch_handlers() do
    %{
      "lobbyHost/respondToJoinRequest/request" => &execute/3
    }
  end

  @spec execute(T.tachyon_conn(), T.tachyon_object(), map) ::
          {T.tachyon_response(), T.tachyon_conn()}
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
