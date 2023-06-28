defmodule Teiserver.Tachyon.Handlers.LobbyChat.SayRequest do
  @moduledoc """

  """
  alias Teiserver.Data.Types, as: T
  alias Teiserver.Battle.Lobby
  alias Teiserver.Tachyon.Responses.LobbyChat.SayResponse

  @spec dispatch_handlers :: map()
  def dispatch_handlers() do
    %{
      "lobbyChat/say/request" => &execute/3
    }
  end

  @spec execute(T.tachyon_conn(), map, map) ::
          {{T.tachyon_command(), T.tachyon_object()}, T.tachyon_conn()}
  def execute(%{lobby_id: nil} = conn, _, _meta) do
    response = SayResponse.generate(:no_lobby)
    {response, conn}
  end

  def execute(conn, %{"message" => message}, _meta) do
    result = if Lobby.allow?(conn.userid, :saybattle, conn.lobby_id) do
      Lobby.say(conn.userid, message, conn.lobby_id)
      true
    else
      false
    end


    response = SayResponse.generate(result)

    {response, conn}
  end
end
