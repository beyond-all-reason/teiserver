defmodule Barserver.Tachyon.Handlers.Lobby.JoinRequest do
  @moduledoc """

  """
  alias Barserver.Data.Types, as: T
  alias Barserver.Battle
  alias Barserver.Tachyon.Responses.Lobby.JoinResponse

  @spec dispatch_handlers :: map()
  def dispatch_handlers() do
    %{
      "lobby/join/request" => &execute/3
    }
  end

  @spec execute(T.tachyon_conn(), T.tachyon_object(), map) ::
          {T.tachyon_response(), T.tachyon_conn()}
  def execute(conn, %{"lobby_id" => lobby_id} = object, _meta) do
    result = Battle.can_join?(conn.userid, lobby_id, object["password"])

    response = JoinResponse.generate(result)

    {response, conn}
  end
end
