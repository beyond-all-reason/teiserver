defmodule Barserver.Tachyon.Responses.Lobby.ClosedResponse do
  @moduledoc """

  """

  alias Barserver.Data.Types, as: T

  @spec generate(T.lobby_id()) :: T.tachyon_response()
  def generate(lobby_id) do
    {"lobby/closed/response", :success, %{"lobby_id" => lobby_id}}
  end
end
