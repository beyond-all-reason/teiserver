defmodule Teiserver.Tachyon.Handlers.LobbyHost.CreateRequest do
  @moduledoc false
  alias Teiserver.Data.Types, as: T
  alias Teiserver.Tachyon.Responses.LobbyHost.CreateResponse
  alias Teiserver.{Lobby, Account}

  @spec dispatch_handlers :: map()
  def dispatch_handlers() do
    %{
      "lobbyHost/create/request" => &execute/3
    }
  end

  @spec execute(T.tachyon_conn(), T.tachyon_object(), map) :: {T.tachyon_response(), T.tachyon_conn()}
  def execute(conn, object, _meta) do
    user = Account.get_user_by_id(conn.userid)
    client = Account.get_client_by_id(conn.userid)

    object =
      Map.merge(object, %{
        "founder_id" => conn.userid,
        "founder_name" => user.name,
        "ip" => client.ip
      })

    lobby = Lobby.create_new_lobby(object)

    response = CreateResponse.generate(lobby)

    new_conn = case lobby do
      {:ok, %{id: lobby_id}} ->
        %{conn | lobby_id: lobby_id}

      _ ->
        conn
    end

    {response, new_conn}
  end
end
