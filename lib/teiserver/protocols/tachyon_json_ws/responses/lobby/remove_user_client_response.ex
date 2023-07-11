defmodule Teiserver.Tachyon.Responses.Lobby.RemoveUserClientResponse do
  @moduledoc """

  """

  alias Teiserver.Data.Types, as: T

  @spec generate(T.userid(), T.lobby_id()) ::
          {T.tachyon_command(), :success, T.tachyon_object()}
          | {T.tachyon_command(), T.error_pair()}
  def generate(userid, lobby_id) when is_integer(userid) and is_integer(lobby_id) do
    {"lobby/removeUserClient/response", :success,
     %{
       "lobby_id" => lobby_id,
       "userid" => userid
     }}
  end
end
