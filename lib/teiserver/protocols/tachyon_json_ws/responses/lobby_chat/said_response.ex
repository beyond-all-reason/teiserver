defmodule Teiserver.Tachyon.Responses.LobbyChat.SaidResponse do
  @moduledoc """

  """
  alias Teiserver.Data.Types, as: T

  @spec generate(T.userid(), T.lobby_id(), String.t()) ::
          {T.tachyon_command(), :success, T.tachyon_object()}
          | {T.tachyon_command(), T.error_pair()}
  def generate(userid, lobby_id, message) when is_integer(userid) and is_integer(lobby_id) do
    {"lobbyChat/said/response", :success,
     %{
       "userid" => userid,
       "lobby_id" => lobby_id,
       "message" => message
     }}
  end
end
