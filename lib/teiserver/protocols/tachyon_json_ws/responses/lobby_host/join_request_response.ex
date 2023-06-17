defmodule Teiserver.Tachyon.Responses.LobbyHost.JoinRequestReponse do
  @moduledoc false

  alias Teiserver.Data.Types, as: T

  @spec generate(T.userid, T.lobby_id()) :: {T.tachyon_command(), T.tachyon_object()}
  def generate(userid, lobby_id) do
    object = %{
      userid: userid,
      lobby_id: lobby_id
    }

    {"lobbyHost/joinRequest/response", :success, object}
  end
end
