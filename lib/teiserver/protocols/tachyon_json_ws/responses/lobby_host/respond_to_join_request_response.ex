defmodule Barserver.Tachyon.Responses.LobbyHost.RespondToJoinRequestResponse do
  @moduledoc false

  alias Barserver.Data.Types, as: T

  @spec generate(atom) :: {T.tachyon_command(), T.tachyon_object()}
  def generate(:ok) do
    {"lobbyHost/respondToJoinRequest/response", :success, %{}}
  end
end
