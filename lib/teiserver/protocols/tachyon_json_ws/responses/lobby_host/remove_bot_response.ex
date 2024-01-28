defmodule Barserver.Tachyon.Responses.LobbyHost.RemoveBotResponse do
  @moduledoc """
  Updated status response - https://github.com/beyond-all-reason/tachyon/blob/master/src/schema/lobby_host.ts
  """

  alias Barserver.Data.Types, as: T

  @spec generate() :: {T.tachyon_command(), T.tachyon_object()}
  def generate() do
    object = %{}

    {"lobbyHost/remove_bot/response", :success, object}
  end
end
