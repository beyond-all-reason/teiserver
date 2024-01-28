defmodule Barserver.Tachyon.Responses.Lobby.ReceivedJoinRequestResponseResponse do
  @moduledoc """

  """

  alias Barserver.Data.Types, as: T

  @spec generate(map()) ::
          {T.tachyon_command(), :success, T.tachyon_object()}
          | {T.tachyon_command(), T.error_pair()}
  def generate(%{response: :accept, lobby_id: lobby_id}) do
    {"lobby/receivedJoinRequestResponse/response", :success,
     %{"result" => "accept", "lobby_id" => lobby_id}}
  end

  def generate(%{response: :deny, lobby_id: lobby_id, reason: reason}) do
    {"lobby/receivedJoinRequestResponse/response", :success,
     %{"result" => "deny", "lobby_id" => lobby_id, "reason" => reason}}
  end
end
