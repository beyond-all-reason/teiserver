defmodule Teiserver.Lobby.Commands.NoCommand do
  @moduledoc """
  Default no command
  """

  alias Teiserver.Data.Types, as: T
  @behaviour Teiserver.Lobby.LobbyCommandBehaviour

  @impl Teiserver.Lobby.LobbyCommandBehaviour
  @spec name() :: String.t()
  def name, do: "no-command"

  @impl Teiserver.Lobby.LobbyCommandBehaviour
  @spec execute(T.lobby_server_state(), map) :: T.lobby_server_state()
  def execute(state, _cmd) do
    state
  end
end
