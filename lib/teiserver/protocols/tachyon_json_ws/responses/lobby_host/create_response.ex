defmodule Teiserver.Tachyon.LobbyHost.CreateResponse do
  @moduledoc """
  Updated status response - https://github.com/beyond-all-reason/tachyon/blob/master/src/schema/lobby_host.ts
  """

  alias Teiserver.Data.Types, as: T

  @spec execute(T.lobby()) :: {T.tachyon_command, T.tachyon_object}
  def execute(lobby) do
    {"lobby_host/create/response", lobby}
  end
end
