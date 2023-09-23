defmodule Teiserver.Lobby.Commands.LobbyCommandBehaviour do
  alias Teiserver.Data.Types, as: T
  @moduledoc """
  Lobby commands are executed from within lobbies.
  """

  @doc """

  """
  @callback name() :: String.t

  @doc """

  """
  @callback execute(state :: T.lobby_server_state, command :: map) :: T.lobby_server_state
end
