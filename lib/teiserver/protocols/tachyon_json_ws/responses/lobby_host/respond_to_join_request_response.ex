defmodule Teiserver.Tachyon.Responses.LobbyHost.RespondToJoinRequestResponse do
  @moduledoc false

  alias Teiserver.Data.Types, as: T

  @spec generate(atom) :: {T.tachyon_command(), T.tachyon_object()}
  def generate(:ok) do
    {"lobbyHost/respondToJoinRequest/response", :success, %{}}
  end
end
