defmodule Teiserver.Tachyon.Handlers.Lobby.LeaveRequest do
  @moduledoc """

  """
  alias Phoenix.PubSub
  alias Teiserver.Lobby
  alias Teiserver.Data.Types, as: T
  alias Teiserver.Tachyon.Responses.Lobby.LeaveResponse

  @spec dispatch_handlers :: map()
  def dispatch_handlers() do
    %{
      "lobby/leave/request" => &execute/3
    }
  end

  @spec execute(T.tachyon_conn(), T.tachyon_object(), map) :: {T.tachyon_response(), T.tachyon_conn()}
  def execute(conn, _object, _meta) do
    # Remove them from all the battles anyways, just in case
    Lobby.remove_user_from_any_lobby(conn.userid)
    |> Enum.each(fn lobby_id ->
      PubSub.unsubscribe(Central.PubSub, "teiserver_lobby_updates:#{lobby_id}")
      PubSub.unsubscribe(Central.PubSub, "teiserver_lobby_chat:#{lobby_id}")
    end)

    response = LeaveResponse.generate(:ok)

    {response, %{conn | lobby_host: false, lobby_id: nil}}
  end
end
