defmodule Teiserver.Tachyon.Responses.Lobby.ListLobbiesResponse do
  @moduledoc """
  Updated status response - https://github.com/beyond-all-reason/tachyon/blob/master/src/schema/lobby_host.ts
  """

  alias Teiserver.Data.Types, as: T

  @spec execute({:error, String.t()} | T.lobby()) :: {T.tachyon_command(), T.tachyon_object()}
  def execute({:error, reason}) do
    {"system/error/response",
     %{
       "command" => "lobby_host/create/request",
       "reason" => reason
     }}
  end

  def execute(lobbies) do
    {"lobby/list_lobbies/response", %{"lobbies" => lobbies}}
  end
end
