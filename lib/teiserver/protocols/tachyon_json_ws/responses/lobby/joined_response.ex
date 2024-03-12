defmodule Barserver.Tachyon.Responses.Lobby.JoinedResponse do
  @moduledoc """

  """

  alias Barserver.Data.Types, as: T

  @spec generate(T.lobby_id(), String.t()) ::
          {T.tachyon_command(), :success, T.tachyon_object()}
          | {T.tachyon_command(), T.error_pair()}
  def generate(lobby_id, script_password) when is_integer(lobby_id) do
    {"lobby/joined/response", :success,
     %{
       "lobby_id" => lobby_id,
       "script_password" => script_password
     }}
  end
end
