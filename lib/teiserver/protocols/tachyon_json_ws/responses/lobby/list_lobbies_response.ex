defmodule Teiserver.Tachyon.Responses.Lobby.ListLobbiesResponse do
  @moduledoc """
  Updated status response - https://github.com/beyond-all-reason/tachyon/blob/master/src/schema/lobby_host.ts
  """

  alias Teiserver.Data.Types, as: T

  @spec generate({:error, String.t()} | T.lobby()) :: {T.tachyon_command(), T.tachyon_object()}
  def generate({:error, reason}) do
    {"system/error/response", :error, reason}
  end

  def generate(lobbies) do
    {"lobby/list_lobbies/response", :success, %{"lobbies" => lobbies}}
  end
end
