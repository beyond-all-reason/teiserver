defmodule Teiserver.Tachyon.Handlers.LobbyHost.CreateRequest do
  @moduledoc """

  """
  alias Teiserver.Data.Types, as: T
  alias Teiserver.Tachyon.Responses.LobbyHost.CreateResponse
  alias Teiserver.{Battle, Account}

  @spec dispatch_handlers :: map()
  def dispatch_handlers() do
    %{
      "lobbyHost/create/request" => &execute/3
    }
  end

  @spec execute(T.tachyon_conn(), map, map) ::
          {{T.tachyon_command(), T.tachyon_object()}, T.tachyon_conn()}
  def execute(conn, object, _meta) do
    user = Account.get_user_by_id(conn.userid)
    client = Account.get_client_by_id(conn.userid)

    object =
      Map.merge(object, %{
        "founder_id" => conn.userid,
        "founder_name" => user.name,
        "ip" => client.ip
      })

    lobby = Battle.create_new_lobby(object)

    response = CreateResponse.execute(lobby)

    {response, conn}
  end
end
