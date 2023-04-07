defmodule Teiserver.Tachyon.Handlers.LobbyHost.CreateRequest do
  @moduledoc """

  """
  alias Teiserver.Data.Types, as: T
  alias Teiserver.Tachyon.Responses.LobbyHost.CreateResponse
  alias Teiserver.{Battle, Account}

  @spec dispatch_handlers :: map()
  def dispatch_handlers() do
    %{
      "lobby_host/create/request" => &execute/3
    }
  end

  @spec execute(T.tachyon_conn(), map, map) ::
          {{T.tachyon_command(), T.tachyon_object()}, T.tachyon_conn()}
  def execute(conn, object, _meta) do
    user = Account.get_user_by_id(conn.userid)
    client = Account.get_client_by_id(conn.userid)

    lobby =
      %{
        founder_id: conn.userid,
        founder_name: user.name,
        name: object["name"],
        type: object["type"],
        nattype: object["nattype"],
        port: object["port"],
        game_hash: object["game_hash"],
        map_hash: object["map_hash"],
        password: object["password"],
        locked: false,
        engine_name: object["engine_name"],
        engine_version: object["engine_version"],
        map_name: object["map_name"],
        game_name: object["game_name"],
        ip: client.ip
      }
      |> Battle.create_lobby()
      |> Battle.add_lobby()

    response = CreateResponse.execute(lobby)

    {response, conn}
  end
end
