defmodule Teiserver.Tachyon.Responses.LobbyHost.UpdateBotResponse do
  @moduledoc """
  Updated status response - https://github.com/beyond-all-reason/tachyon/blob/master/src/schema/lobby_host.ts
  """

  alias Teiserver.Data.Types, as: T

  @spec generate() :: {T.tachyon_command(), T.tachyon_object()}
  def generate() do
    object = %{}

    {"lobbyHost/update_bot/response", :success, object}
  end
end
