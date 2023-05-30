defmodule Teiserver.Tachyon.Responses.LobbyHost.AddBotResponse do
  @moduledoc """
  Updated status response - https://github.com/beyond-all-reason/tachyon/blob/master/src/schema/lobby_host.ts
  """

  alias Teiserver.Data.Types, as: T

  @spec execute() :: {T.tachyon_command(), T.tachyon_object()}
  def execute() do
    object = %{}

    {"lobbyHost/add_bot/response", :success, object}
  end
end
